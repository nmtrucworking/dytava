#!/usr/bin/env python3
"""Offline QA for the DRAFT Input contract and fixtures, not app adapter tests."""
from __future__ import annotations

import copy
import csv
import hashlib
import io
import json
import re
import unittest
from pathlib import Path
from urllib.parse import unquote

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parent
DOCS = ROOT.parent.parent
SCHEMA_FILES = sorted((ROOT / 'schemas').glob('*.schema.json'))
SCHEMAS = {f.stem.removesuffix('.schema'): json.loads(f.read_text()) for f in SCHEMA_FILES}
REGISTRY = Registry().with_resources((s['$id'], Resource.from_contents(s)) for s in SCHEMAS.values())
VALIDATORS = {name: Draft202012Validator(s, registry=REGISTRY) for name, s in SCHEMAS.items()}


def load(name):
    return json.loads((ROOT / 'fixtures' / name).read_text())


def validate(name, value):
    VALIDATORS[name].validate(value)


def check_manifest(manifest):
    assert set(manifest) == {'schema_version', 'session_id', 'artifacts'}
    assert manifest['schema_version'] == '0.1.0' and manifest['session_id']
    artifacts = manifest['artifacts']
    assert len(artifacts) == 2 and {x['source_side'] for x in artifacts} == {'A', 'B'}
    assert len({x['artifact_id'] for x in artifacts}) == 2
    for artifact in artifacts:
        validate('input_artifact', artifact)


def check_bindings(manifest, config, tables):
    """Cross-record fixture checks that JSON Schema cannot express."""
    check_manifest(manifest)
    validate('import_config', config)
    artifacts = {x['artifact_id']: x for x in manifest['artifacts']}
    assert len({x['table_id'] for x in tables}) == len(tables)
    for side in ('a', 'b'):
        source = config[f'source_{side}']
        artifact = artifacts[source['artifact_id']]
        assert artifact['source_side'] == side.upper()
        assert artifact['format'] == source['format']
        assert artifact['selected_scope'] == source['scopes']
    for table in tables:
        validate('source_table', table)
        artifact = artifacts[table['artifact_id']]
        assert table['source_range'] in artifact['selected_scope']
        fields = table['fields']
        assert len({f['field_id'] for f in fields}) == len(fields)
        indices = [f['source_index'] for f in fields]
        assert indices == sorted(set(indices))
        assert table['row_count'] == len(table['rows'])
        assert len({r['row_id'] for r in table['rows']}) == len(table['rows'])
        for row in table['rows']:
            assert len(row['cells']) == len(fields)
            for field, cell in zip(fields, row['cells']):
                ref = cell['source_ref']
                assert ref['artifact_id'] == table['artifact_id']
                if ref['type'] == 'csv':
                    assert ref['line'] <= ref['end_line']
                    assert ref['record'] == row['source_record']
                    assert ref['field'] == field['source_index']


class InputContractTests(unittest.TestCase):
    def setUp(self):
        self.manifest = load('input_manifest.example.json')
        self.config = load('import_config.example.json')
        self.tables = load('source_tables.expected.json')

    def rejected(self, schema, value):
        self.assertFalse(VALIDATORS[schema].is_valid(value), f'{schema} unexpectedly accepted invalid sample')

    def cell(self, kind='jsonNull', **updates):
        cell = {'raw_kind': kind, 'lexical_status': 'NOT_APPLICABLE',
                'formula_cache_status': 'NOT_FORMULA', 'null_kind': 'JSON_NULL',
                'source_ref': {'type': 'json', 'artifact_id': 'fixture-json', 'exists': True, 'pointer': '/0/x'},
                'losses': [], 'review_state': 'NOT_REQUIRED'}
        cell.update(updates)
        return cell

    def test_schema_meta_and_offline_references(self):
        self.assertEqual(set(SCHEMAS), {'input_artifact', 'source_table', 'source_cell', 'source_ref', 'import_config'})
        for schema in SCHEMAS.values():
            Draft202012Validator.check_schema(schema)
        check_bindings(self.manifest, self.config, self.tables)

    def test_manifest_hashes_and_actual_byte_sizes(self):
        for artifact in self.manifest['artifacts']:
            data = (ROOT / 'fixtures' / artifact['file_name']).read_bytes()
            self.assertEqual(artifact['size_bytes'], len(data))
            self.assertEqual(artifact['sha256'], hashlib.sha256(data).hexdigest())
            self.assertFalse(data.startswith(b'\xef\xbb\xbf'))
            self.assertNotIn(b'\r', data)

    def test_csv_oracle_and_multiline_source_positions(self):
        for table, side in zip(self.tables, ('a', 'b')):
            data = (ROOT / 'fixtures' / f'sample_{side}.csv').read_text()
            reader = csv.reader(io.StringIO(data, newline=''), strict=True)
            headers = next(reader)
            self.assertEqual(headers, [f['header_text'] for f in table['fields']])
            previous_line = reader.line_num
            parsed = []
            for record, row in enumerate(reader, 2):
                parsed.append(row)
                expected = table['rows'][record - 2]
                self.assertEqual(row, [c['raw_lexeme'] for c in expected['cells']])
                for c in expected['cells']:
                    self.assertEqual((c['source_ref']['line'], c['source_ref']['end_line']),
                                     (previous_line + 1, reader.line_num))
                    self.assertEqual(c['null_kind'], 'EMPTY_STRING' if c['raw_lexeme'] == '' else 'NONE')
                previous_line = reader.line_num
            self.assertEqual(len(parsed), 3)
            self.assertEqual(parsed[0][0], '00123')
            self.assertEqual(parsed[0][3], 'dòng 1\ndòng 2')
            self.assertEqual(parsed[1][3], '')
            self.assertEqual(parsed[2][3], 'x,y')

    def test_null_missing_blank_and_error_are_distinct(self):
        null = self.cell()
        validate('source_cell', null)
        bad = {**null, 'raw_lexeme': ''}
        self.rejected('source_cell', bad)
        missing = self.cell('missing', null_kind='MISSING', source_ref={**null['source_ref'], 'exists': False})
        validate('source_cell', missing)
        self.rejected('source_cell', {**missing, 'source_ref': null['source_ref']})
        excel = {'type': 'excel', 'artifact_id': 'xlsx', 'exists': True, 'sheet': 'Sheet 1', 'address': 'A1'}
        validate('source_cell', self.cell('blank', null_kind='BLANK', source_ref=excel))
        validate('source_cell', self.cell('error', null_kind='EXCEL_ERROR', source_ref=excel,
                                        lexical_status='PRESERVED', raw_lexeme='#N/A'))
        empty = self.tables[0]['rows'][1]['cells'][3]
        validate('source_cell', empty)
        self.rejected('source_cell', {**empty, 'null_kind': 'MISSING'})
        self.rejected('source_cell', {**empty, 'raw_lexeme': 'not empty'})

    def test_number_precision_and_numeric_display_separation(self):
        c = self.cell('jsonNumber', null_kind='NONE', lexical_status='PRESERVED', raw_lexeme='9007199254740993')
        validate('source_cell', c)
        for token in ('00123', 'NaN', '1,234'):
            self.rejected('source_cell', {**c, 'raw_lexeme': token})
        excel = {'type': 'excel', 'artifact_id': 'xlsx', 'exists': True, 'sheet': 'S', 'address': 'A1'}
        c.update(raw_kind='xlsxNumber', raw_lexeme='123', display_text='00123', format_code='00000', source_ref=excel)
        validate('source_cell', c)
        self.assertNotEqual(c['raw_lexeme'], c['display_text'])
        unavailable = {**c, 'lexical_status': 'UNAVAILABLE'}
        del unavailable['raw_lexeme']
        self.rejected('source_cell', unavailable)
        unavailable['losses'] = ['RAW_LEXEME_UNAVAILABLE']
        validate('source_cell', unavailable)

    def test_formula_cache_contract(self):
        c = self.cell('formula', null_kind='NONE', lexical_status='PRESERVED', raw_lexeme='SUM(A1:A2)',
                      formula='SUM(A1:A2)', formula_cache_status='MISSING',
                      source_ref={'type': 'excel', 'artifact_id': 'xlsx', 'exists': True, 'sheet': 'S', 'address': 'B1'})
        validate('source_cell', c)
        self.rejected('source_cell', {**c, 'cached_value': {'raw_kind': 'xlsxNumber', 'raw_lexeme': '0'}})
        for state in ('PRESENT_UNVERIFIED', 'KNOWN_STALE'):
            self.rejected('source_cell', {**c, 'formula_cache_status': state})
            validate('source_cell', {**c, 'formula_cache_status': state,
                                    'cached_value': {'raw_kind': 'xlsxNumber', 'raw_lexeme': '3'}})
        self.rejected('source_cell', {**c, 'raw_kind': 'csvText'})

    def test_source_ref_union_and_json_pointer_escaping(self):
        for pointer in ('', '/0/a~1b~0', '/a b', '//'):
            validate('source_ref', {'type': 'json', 'artifact_id': 'j', 'exists': True, 'pointer': pointer})
        for pointer in ('/bad~2', 'a/b', '/bad~'):
            self.rejected('source_ref', {'type': 'json', 'artifact_id': 'j', 'exists': True, 'pointer': pointer})
        csv_ref = self.tables[0]['rows'][0]['cells'][0]['source_ref']
        self.rejected('source_ref', {**csv_ref, 'address': 'A1'})
        self.rejected('source_ref', {**csv_ref, 'line': 0})
        self.rejected('source_ref', {**csv_ref, 'type': 'excel'})
        c = self.tables[0]['rows'][0]['cells'][0]
        self.rejected('source_cell', {**c, 'source_ref': {'type': 'excel', 'artifact_id': 'a',
                         'exists': True, 'sheet': 'Fake', 'address': 'A1'}})

    def test_ocr_requires_review_and_preserves_recognized_text(self):
        ref = {'type': 'ocr', 'artifact_id': 'image', 'exists': True, 'page': 1,
               'polygon': [{'x': 1, 'y': 1}, {'x': 8, 'y': 1}, {'x': 8, 'y': 8}],
               'coordinate_space': 'oriented_image_pixels', 'image_width': 10, 'image_height': 10}
        for confidence in (0.99, 0.2, None):
            c = self.cell('ocrText', null_kind='NONE', lexical_status='PRESERVED', raw_lexeme='OO123',
                          confidence=confidence, review_state='PENDING', source_ref=ref)
            validate('source_cell', c)
            self.rejected('source_cell', {**c, 'review_state': 'NOT_REQUIRED'})
            self.rejected('source_cell', {**c, 'review_state': 'CONFIRMED'})
            validate('source_cell', {**c, 'review_state': 'CONFIRMED', 'reviewed_text': '00123'})
            self.assertEqual(c['raw_lexeme'], 'OO123')

    def test_config_and_artifact_constraints(self):
        validate('import_config', self.config)
        for extra in ('alignment', 'keys', 'policy', 'tolerance'):
            self.rejected('import_config', {**self.config, extra: {}})
        c = copy.deepcopy(self.config)
        c['source_a']['delimiter'] = '||'
        self.rejected('import_config', c)
        c = copy.deepcopy(self.config)
        c['source_a']['format'] = 'xlsx'  # Still has CSV-only scope/encoding/delimiter.
        self.rejected('import_config', c)
        a = copy.deepcopy(self.manifest['artifacts'][0])
        a['sha256'] = 'not-a-hash'
        self.rejected('input_artifact', a)
        # Lifecycle unknowns are explicit, not fabricated metadata.
        a.update(sha256=None, size_bytes=None, format=None, selected_scope=None)
        validate('input_artifact', a)

    def test_non_csv_config_profiles(self):
        for format_, scopes, header, encoding, delimiter in (
            ('xlsx', [{'kind': 'excel', 'sheet_name': 'Data', 'range': 'A1:D9'}],
             {'mode': 'explicit', 'row': 1}, None, None),
            ('json', [{'kind': 'json', 'records_pointer': ''}], {'mode': 'none'}, None, None),
            ('tsv', [{'kind': 'delimited', 'first_record': 1, 'last_record': None}],
             {'mode': 'explicit', 'row': 1}, 'UTF-8', '\t'),
        ):
            config = copy.deepcopy(self.config)
            config['source_a'].update(format=format_, scopes=scopes, header=header,
                                      encoding=encoding, delimiter=delimiter)
            with self.subTest(format=format_):
                validate('import_config', config)
        config['source_a']['delimiter'] = ','
        self.rejected('import_config', config)

    def test_boolean_storage_lexemes_are_not_text_aliases(self):
        c = self.cell('jsonBoolean', null_kind='NONE', lexical_status='PRESERVED', raw_lexeme='false')
        validate('source_cell', c)
        self.rejected('source_cell', {**c, 'raw_lexeme': 'Không'})
        c.update(raw_kind='xlsxBoolean', raw_lexeme='0',
                 source_ref={'type': 'excel', 'artifact_id': 'xlsx', 'exists': True,
                             'sheet': 'S', 'address': 'A1'})
        validate('source_cell', c)
        self.rejected('source_cell', {**c, 'raw_lexeme': 'false'})

    def test_cross_record_mutations_are_rejected(self):
        c = copy.deepcopy(self.config)
        c['source_a']['artifact_id'] = 'fixture-b'
        validate('import_config', c)  # Shape alone cannot detect wrong side.
        with self.assertRaises(AssertionError):
            check_bindings(self.manifest, c, self.tables)
        for mutation in ('count', 'cells', 'artifact', 'field_id', 'line'):
            tables = copy.deepcopy(self.tables)
            t = tables[0]
            if mutation == 'count': t['row_count'] += 1
            if mutation == 'cells': t['rows'][0]['cells'].pop()
            if mutation == 'artifact': t['rows'][0]['cells'][0]['source_ref']['artifact_id'] = 'fixture-b'
            if mutation == 'field_id': t['fields'][1]['field_id'] = t['fields'][0]['field_id']
            if mutation == 'line': t['rows'][0]['cells'][0]['source_ref']['line'] = 99
            with self.subTest(mutation=mutation), self.assertRaises(AssertionError):
                check_bindings(self.manifest, self.config, tables)

    def test_traceability_and_registry_consistency(self):
        registry = load('acceptance_registry.json')
        ids = [x['id'] for x in registry]
        self.assertEqual(ids, [f'INP-TC-{i:03}' for i in range(1, 41)])
        spec = (ROOT / '09_acceptance_tests.md').read_text()
        readme = (ROOT / 'README.md').read_text()
        all_docs = '\n'.join(f.read_text() for f in ROOT.glob('*.md'))
        requirements = {f'INP-REQ-{i:03}' for i in range(1, 13)}
        covered = set()
        for case in registry:
            self.assertEqual(case['status'], 'PLANNED')
            self.assertIn(case['expected'], spec)
            self.assertIn(case['procedure'], spec)
            self.assertIn(f"| {case['id']} |", spec)
            for req in case['requirements']:
                self.assertIn(req, requirements)
                self.assertIn(f'| {req} |', readme)
                covered.add(req)
            for rule in case['rules']:
                self.assertIn(rule, all_docs)
        self.assertEqual(covered, requirements)
        rule_definitions = re.findall(r'\*\*(INP-RULE-\d{3}):?\*\*|^\|(INP-RULE-\d{3})\|', all_docs, re.M)
        rule_ids = [a or b for a, b in rule_definitions]
        self.assertEqual(len(rule_ids), 40)
        self.assertEqual(len(set(rule_ids)), 40)

    def test_document_metadata_and_local_links(self):
        # Check current document entry points and their local links.
        files = list(ROOT.glob('*.md')) + [ROOT / 'fixtures/README.md', DOCS / 'README.md',
                  DOCS / 'project/Project Description.md', DOCS / 'examples/README.md',
                  DOCS / 'diagrams/README.md',
                  DOCS / 'project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/EXCELCOMPARE_MASTER_ANDROID_IOS.md',
                  DOCS / 'project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/DATATYPE_POLICY_ENGINE_ANDROID_IOS_SPEC.md',
                  DOCS / 'project/EXCELCOMPARE_Android_iPhone_Flutter_Package_2026-11-11/README_START_HERE.md',
                  DOCS.parent / 'packages/excelcompare_core/README.md']
        for path in ROOT.glob('*.md'):
            if path.name == 'README.md': continue
            text = path.read_text()
            self.assertIn('Status: DRAFT', text)
            self.assertIn('Owner: TBD', text)
            self.assertEqual(len(re.findall(r'^## \d+\.', text, re.M)), 11)
        for path in files:
            for target in re.findall(r'\]\(([^)\n]+)\)', path.read_text()):
                if re.match(r'^[a-z]+:', target) or target.startswith('#'): continue
                target = unquote(target.split('#', 1)[0])
                self.assertTrue((path.parent / target).exists(), f'{path}: broken link {target}')


if __name__ == '__main__':
    unittest.main(verbosity=2)
