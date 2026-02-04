"""
Log Parser Application
A web-based tool for viewing, filtering, and searching application logs.
"""

import csv
import json
import os
import re
from datetime import datetime
from flask import Flask, render_template, request, jsonify
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB max file size
app.config['UPLOAD_FOLDER'] = 'uploads'

# Ensure upload folder exists
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# Global storage for parsed logs
parsed_logs = []


def parse_nested_json(log_string):
    """Parse the nested JSON from the log field."""
    try:
        # The log field contains a timestamp prefix followed by JSON
        # Format: "2026-02-02T06:33:49.361976983Z stderr F {...}"
        match = re.search(r'stderr F ({.*})$', log_string)
        if match:
            return json.loads(match.group(1))
    except (json.JSONDecodeError, AttributeError):
        pass
    return None


def parse_csv_logs(filepath):
    """Parse the CSV log file and extract relevant fields."""
    logs = []
    
    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            try:
                # Parse the nested JSON log
                log_json = parse_nested_json(row.get('_source.log', ''))
                
                log_entry = {
                    'id': row.get('_id', ''),
                    'index': row.get('_index', ''),
                    'timestamp': row.get('_source.@timestamp', ''),
                    'pod_name': row.get('_source.kubernetes.pod_name', ''),
                    'namespace': row.get('_source.kubernetes.namespace_name', ''),
                    'container_name': row.get('_source.kubernetes.container_name', ''),
                    'host': row.get('_source.kubernetes.host', ''),
                    'container_image': row.get('_source.kubernetes.container_image', ''),
                    'log_group': row.get('_source.@log_group', ''),
                    'raw_log': row.get('_source.log', ''),
                }
                
                # Add parsed JSON fields if available
                if log_json:
                    log_entry['level'] = log_json.get('level', 'unknown')
                    log_entry['message'] = log_json.get('message', '')
                    log_entry['trace_id'] = log_json.get('traceId', '')
                    log_entry['image_tag'] = log_json.get('imageTag', '')
                    log_entry['upstream_system'] = log_json.get('upstreamSystem', '')
                    log_entry['marketplace_id'] = log_json.get('marketplaceID', '')
                    log_entry['external_id'] = log_json.get('externalID', '')
                    log_entry['caller'] = log_json.get('caller', '')
                    log_entry['log_time'] = log_json.get('time', '')
                else:
                    log_entry['level'] = 'unknown'
                    log_entry['message'] = row.get('_source.log', '')[:200]
                    log_entry['trace_id'] = ''
                    log_entry['image_tag'] = ''
                    log_entry['upstream_system'] = ''
                    log_entry['marketplace_id'] = ''
                    log_entry['external_id'] = ''
                    log_entry['caller'] = ''
                    log_entry['log_time'] = ''
                
                logs.append(log_entry)
            except Exception as e:
                print(f"Error parsing row: {e}")
                continue
    
    return logs


def filter_logs(logs, filters):
    """Filter logs based on provided criteria."""
    filtered = logs
    
    # Text search across multiple fields
    if filters.get('search'):
        search_term = filters['search'].lower()
        filtered = [
            log for log in filtered
            if search_term in log.get('message', '').lower()
            or search_term in log.get('trace_id', '').lower()
            or search_term in log.get('pod_name', '').lower()
            or search_term in log.get('external_id', '').lower()
            or search_term in log.get('caller', '').lower()
            or search_term in log.get('raw_log', '').lower()
        ]
    
    # Filter by log level (supports multiple levels)
    if filters.get('levels') and filters['levels'] != ['all'] and 'all' not in filters['levels']:
        filtered = [log for log in filtered if log.get('level') in filters['levels']]
    
    # Filter by pod name
    if filters.get('pod_name') and filters['pod_name'] != 'all':
        filtered = [log for log in filtered if log.get('pod_name') == filters['pod_name']]
    
    # Filter by namespace
    if filters.get('namespace') and filters['namespace'] != 'all':
        filtered = [log for log in filtered if log.get('namespace') == filters['namespace']]
    
    # Filter by external ID
    if filters.get('external_id') and filters['external_id'] != 'all':
        filtered = [log for log in filtered if log.get('external_id') == filters['external_id']]
    
    # Filter by date range
    if filters.get('start_date'):
        filtered = [
            log for log in filtered
            if log.get('timestamp', '') >= filters['start_date']
        ]
    
    if filters.get('end_date'):
        filtered = [
            log for log in filtered
            if log.get('timestamp', '') <= filters['end_date']
        ]
    
    return filtered


@app.route('/')
def index():
    """Render the main page."""
    return render_template('index.html')


@app.route('/upload', methods=['POST'])
def upload_file():
    """Handle file upload and parse logs."""
    global parsed_logs
    
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400
    
    if file and file.filename.endswith('.csv'):
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        try:
            parsed_logs = parse_csv_logs(filepath)
            
            # Get unique values for filters
            levels = sorted(set(log.get('level', 'unknown') for log in parsed_logs))
            pod_names = sorted(set(log.get('pod_name', '') for log in parsed_logs if log.get('pod_name')))
            namespaces = sorted(set(log.get('namespace', '') for log in parsed_logs if log.get('namespace')))
            external_ids = sorted(set(log.get('external_id', '') for log in parsed_logs if log.get('external_id')))
            
            return jsonify({
                'success': True,
                'total_logs': len(parsed_logs),
                'filters': {
                    'levels': levels,
                    'pod_names': pod_names,
                    'namespaces': namespaces,
                    'external_ids': external_ids
                }
            })
        except Exception as e:
            return jsonify({'error': f'Error parsing file: {str(e)}'}), 500
    
    return jsonify({'error': 'Invalid file type. Please upload a CSV file.'}), 400


@app.route('/logs', methods=['GET'])
def get_logs():
    """Get filtered logs with pagination."""
    global parsed_logs
    
    # Get filter parameters
    # Parse levels as a list (comma-separated)
    levels_param = request.args.get('levels', 'all')
    levels_list = [l.strip() for l in levels_param.split(',') if l.strip()]
    
    filters = {
        'search': request.args.get('search', ''),
        'levels': levels_list if levels_list else ['all'],
        'pod_name': request.args.get('pod_name', 'all'),
        'namespace': request.args.get('namespace', 'all'),
        'external_id': request.args.get('external_id', 'all'),
        'start_date': request.args.get('start_date', ''),
        'end_date': request.args.get('end_date', '')
    }
    
    # Pagination parameters
    page = int(request.args.get('page', 1))
    per_page = int(request.args.get('per_page', 50))
    
    # Sort parameters
    sort_by = request.args.get('sort_by', 'timestamp')
    sort_order = request.args.get('sort_order', 'desc')
    
    # Filter logs
    filtered = filter_logs(parsed_logs, filters)
    
    # Sort logs
    sort_key_map = {
        'level': 'level',
        'timestamp': 'log_time',
        'message': 'message',
        'pod': 'pod_name',
        'trace_id': 'trace_id',
        'caller': 'caller'
    }
    
    sort_field = sort_key_map.get(sort_by, 'log_time')
    reverse = sort_order == 'desc'
    
    def parse_timestamp(ts):
        """Parse various timestamp formats into a datetime for proper sorting."""
        if not ts:
            return None
        try:
            # ISO format: 2026-01-15T10:30:00Z or 2026-01-15T10:30:00.123456Z
            if 'T' in ts:
                # Remove timezone suffix and microseconds for parsing
                clean_ts = ts.replace('Z', '').split('.')[0]
                return datetime.strptime(clean_ts, '%Y-%m-%dT%H:%M:%S')
            # Format: 01/15/2026 10:30:00 AM
            elif '/' in ts:
                try:
                    return datetime.strptime(ts, '%m/%d/%Y %I:%M:%S %p')
                except:
                    try:
                        return datetime.strptime(ts, '%m/%d/%Y %H:%M:%S')
                    except:
                        return None
            # Format: 2026-01-15 10:30:00
            elif '-' in ts and ' ' in ts:
                return datetime.strptime(ts.split('.')[0], '%Y-%m-%d %H:%M:%S')
        except:
            pass
        return None
    
    # Handle sorting with fallback for empty values
    def get_sort_key(log):
        value = log.get(sort_field, '')
        if sort_field == 'log_time':
            # Fallback to timestamp if log_time is empty
            value = value or log.get('timestamp', '')
            # Parse timestamp for proper sorting
            parsed = parse_timestamp(value)
            if parsed:
                return parsed
            # If parsing fails, return minimum date so it sorts to the end
            return datetime.min if not reverse else datetime.max
        return (value or '').lower() if isinstance(value, str) else (value or '')
    
    filtered.sort(key=get_sort_key, reverse=reverse)
    
    # Paginate
    total = len(filtered)
    start = (page - 1) * per_page
    end = start + per_page
    paginated = filtered[start:end]
    
    return jsonify({
        'logs': paginated,
        'total': total,
        'page': page,
        'per_page': per_page,
        'total_pages': (total + per_page - 1) // per_page
    })


@app.route('/log/<log_id>', methods=['GET'])
def get_log_detail(log_id):
    """Get detailed view of a single log entry."""
    global parsed_logs
    
    for log in parsed_logs:
        if log.get('id') == log_id:
            return jsonify(log)
    
    return jsonify({'error': 'Log not found'}), 404


@app.route('/stats', methods=['GET'])
def get_stats():
    """Get statistics about the loaded logs."""
    global parsed_logs
    
    if not parsed_logs:
        return jsonify({'error': 'No logs loaded'}), 404
    
    # Count by level
    level_counts = {}
    for log in parsed_logs:
        level = log.get('level', 'unknown')
        level_counts[level] = level_counts.get(level, 0) + 1
    
    # Timeline data - group by hour
    timeline = {}
    for log in parsed_logs:
        timestamp = log.get('log_time', log.get('timestamp', ''))
        if timestamp:
            try:
                # Parse the timestamp and round to hour
                if 'T' in timestamp:
                    hour = timestamp[:13] + ':00:00'  # "2026-02-02T06" -> "2026-02-02T06:00:00"
                elif '/' in timestamp:
                    # Handle format like "02/02/2026 6:33:00 am"
                    from datetime import datetime
                    try:
                        dt = datetime.strptime(timestamp, '%m/%d/%Y %I:%M:%S %p')
                        hour = dt.strftime('%Y-%m-%dT%H:00:00')
                    except:
                        try:
                            dt = datetime.strptime(timestamp, '%m/%d/%Y %H:%M:%S')
                            hour = dt.strftime('%Y-%m-%dT%H:00:00')
                        except:
                            continue
                else:
                    # Handle other formats
                    hour = timestamp[:13] + ':00:00'
                timeline[hour] = timeline.get(hour, 0) + 1
            except:
                pass
    
    # Sort timeline by time
    sorted_timeline = dict(sorted(timeline.items()))
    
    return jsonify({
        'total_logs': len(parsed_logs),
        'level_counts': level_counts,
        'timeline': sorted_timeline
    })


if __name__ == '__main__':
    # Bind to 0.0.0.0 to allow access from:
    # - http://localhost:5050
    # - http://127.0.0.1:5050
    # - http://<your-ip>:5050 (from other devices on network)
    # Using port 5050 to avoid conflict with macOS AirPlay Receiver (port 5000)
    app.run(host='0.0.0.0', debug=True, port=5050)
