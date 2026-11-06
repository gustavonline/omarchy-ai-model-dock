def parse_records(text):
    lines = text.strip().splitlines()
    if not lines:
        return []
    headers = lines[0].split(',')
    return [dict(zip(headers, line.split(','))) for line in lines[1:] if line]
