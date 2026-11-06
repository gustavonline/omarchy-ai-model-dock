import unittest
from records import parse_records

class RecordsTest(unittest.TestCase):
    def test_empty(self):
        self.assertEqual(parse_records(''), [])
        self.assertEqual(parse_records(' \n\t\r\n'), [])
    def test_basic(self):
        self.assertEqual(parse_records('name,city\nAda,Copenhagen\n'), [{'name':'Ada','city':'Copenhagen'}])
    def test_comma(self):
        self.assertEqual(parse_records('name,note\nAda,"one,two"\n'), [{'name':'Ada','note':'one,two'}])
    def test_newline(self):
        self.assertEqual(parse_records('name,note\nAda,"first\nsecond"\n'), [{'name':'Ada','note':'first\nsecond'}])
    def test_quotes(self):
        self.assertEqual(parse_records('name,note\nAda,"say ""yes"""\n'), [{'name':'Ada','note':'say "yes"'}])
    def test_header_bom_and_whitespace(self):
        self.assertEqual(parse_records('\ufeff name , city \r\nSøren,Århus\r\n'), [{'name':'Søren','city':'Århus'}])
    def test_values_unchanged(self):
        self.assertEqual(parse_records('name,value\n Ada , 02 \n'), [{'name':' Ada ','value':' 02 '}])
    def test_blank_lines(self):
        self.assertEqual(parse_records('name,city\n\n   \nAda,Copenhagen\n\t\n'), [{'name':'Ada','city':'Copenhagen'}])
    def test_empty_values_are_records(self):
        self.assertEqual(parse_records('name,city\n,\n'), [{'name':'','city':''}])
    def test_duplicate_headers(self):
        with self.assertRaises(ValueError): parse_records(' name,name \nA,B')
    def test_empty_header(self):
        with self.assertRaises(ValueError): parse_records('name, \nA,B')
    def test_short_row(self):
        with self.assertRaises(ValueError): parse_records('a,b\n1')
    def test_extra_row(self):
        with self.assertRaises(ValueError): parse_records('a,b\n1,2,3')
