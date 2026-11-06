# CSV records repair

Fix src/records.py. parse_records(text) returns a list of dictionaries of strings.
Use Python's standard library. Support CSV quoting, doubled quotes, embedded newlines,
Unicode, CRLF and an optional UTF-8 BOM at the very beginning. Strip header whitespace
and reject blank or duplicate header names. Ignore entirely blank records, including
whitespace-only physical lines. Keep field values unchanged. Reject nonblank rows
whose field count differs from the header, using ValueError. Empty input returns [].
Do not change test_records.py or this README. Do not install anything. Work only in
src/records.py, inspect the tests and run them using PYTHONPATH=src python3 -m unittest
-v test_records. Finish with a short account of the change and test results.
