# Log Parser

A web-based log viewer for parsing, filtering, and searching through application logs exported from AWS CloudWatch/Kubernetes.

## Features

- **File Upload**: Drag-and-drop or browse to upload CSV log files
- **Smart Parsing**: Automatically extracts structured data from nested JSON logs
- **Filtering**: Filter by log level, pod name, namespace, external ID
- **Full-Text Search**: Search across messages, trace IDs, pod names, and caller information
- **Pagination**: Efficiently browse through large log files
- **Detail View**: Click any log entry to see complete details including raw log data
- **Modern UI**: Dark theme optimized for log analysis

## Installation

1. Create a virtual environment (recommended):
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Run the application:
   ```bash
   python app.py
   ```

4. Open your browser to `http://localhost:5000`

## Usage

1. **Upload Logs**: Drag and drop a CSV log file onto the upload area, or click to browse
2. **Filter**: Use the filter dropdowns to narrow down by log level, pod, namespace, or external ID
3. **Search**: Type in the search box to find logs containing specific text
4. **View Details**: Click any row to see the full log entry with all metadata

## Supported Log Format

The parser is designed for CSV exports from AWS CloudWatch Container Insights with the following columns:
- `_source.log` - Raw log content with embedded JSON
- `_source.kubernetes.pod_name` - Kubernetes pod name
- `_source.kubernetes.namespace_name` - Kubernetes namespace
- `_source.kubernetes.container_name` - Container name
- `_source.kubernetes.host` - Host information
- `_source.@timestamp` - Log timestamp
- And more...

The parser extracts structured JSON fields including:
- `level` - Log level (info, warning, error, etc.)
- `message` - Log message
- `traceId` - Distributed trace ID
- `caller` - Source code location
- `imageTag` - Container image version
- `externalID` - External reference ID

## License

MIT License
