#!/usr/bin/env python3
"""Download version-pinned public datasets for Dytava, without altering source bytes."""
import argparse
import csv
import hashlib
import json
import shutil
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
CATALOG=json.loads((HERE/'dataset_manifest.json').read_text(encoding='utf-8'))

def workbook_sheets(path):
    try:
        with zipfile.ZipFile(path) as z:
            if 'xl/workbook.xml' not in z.namelist():
                return []
            root=ET.fromstring(z.read('xl/workbook.xml'))
            ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
            return [e.attrib.get('name','') for e in root.findall('.//m:sheets/m:sheet',ns)]
    except (zipfile.BadZipFile,ET.ParseError):
        return None

def file_metadata(path):
    h=hashlib.sha256(); size=0
    with path.open('rb') as f:
        while True:
            chunk=f.read(1024*1024)
            if not chunk:break
            h.update(chunk);size+=len(chunk)
    result={'path':str(path),'size_bytes':size,'sha256':h.hexdigest()}
    if path.suffix.lower() in ('.xlsx','.zip'):
        try:
            with zipfile.ZipFile(path) as z:
                bad=z.testzip()
                result['zip_integrity_ok'] = bad is None
                result['zip_member_count'] = len(z.namelist())
                if path.suffix.lower()=='.zip':
                    result['excel_members']=[n for n in z.namelist() if n.lower().endswith(('.xlsx','.xls','.xlsm','.xlsb'))][:100]
            if path.suffix.lower()=='.xlsx':
                result['worksheets']=workbook_sheets(path)
        except zipfile.BadZipFile:
            result['zip_integrity_ok']=False
    elif path.suffix.lower()=='.csv':
        try:
            with path.open(encoding='utf-8-sig',newline='') as f:
                reader=csv.reader(f)
                header=next(reader,[])
                result['csv_column_count']=len(header)
                result['csv_header_preview']=header[:30]
                result['csv_record_count']=sum(1 for _ in reader)
        except Exception as exc:
            result['csv_parse_error']=str(exc)
    return result

def retrieve(url,dest,timeout=90):
    req=urllib.request.Request(url, headers={'User-Agent':'DytavaResearchCorpus/1.0 (research; browser-compatible)', 'Accept':'*/*'})
    tmp=dest.with_suffix(dest.suffix+'.part')
    try:
        with urllib.request.urlopen(req,timeout=timeout) as response, tmp.open('wb') as f:
            shutil.copyfileobj(response,f,1024*1024)
        if tmp.stat().st_size < 100:
            raise ValueError('Response unexpectedly small; check for HTML/redirect failure')
        with tmp.open('rb') as f:
            prefix=f.read(64).lower()
        if dest.suffix.lower() in ('.zip','.xlsx') and not prefix.startswith(b'pk'):
            raise ValueError('Response not a ZIP/OOXML file; likely an HTML error page')
        if dest.suffix.lower()=='.csv' and (prefix.startswith(b'<!doctype') or prefix.startswith(b'<html')):
            raise ValueError('Response is HTML, not CSV')
        tmp.replace(dest)
    finally:
        if tmp.exists():tmp.unlink()

def main():
    p=argparse.ArgumentParser(description='Fetch 3 original real-world dataset files per group. Does not generate synthetic data.')
    p.add_argument('--group',choices=['G1','G2','G3','G4'],help='Group to fetch')
    p.add_argument('--all',action='store_true',help='Fetch all groups (G4 needs --include-large)')
    p.add_argument('--include-large',action='store_true',help='Allow G4 World Bank WDI ZIP archives')
    p.add_argument('--dry-run',action='store_true',help='Print URLs without downloading')
    p.add_argument('--list',action='store_true',help='Show the curated download catalogue')
    p.add_argument('--output',type=Path,default=HERE/'original_sources',help='Output directory')
    p.add_argument('--force',action='store_true',help='Redownload existing files')
    args=p.parse_args()
    if not args.group and not args.all and not args.list: p.error('Use --group G1..G4, --all, or --list')
    groups=[g for g in CATALOG['groups'] if args.all or args.list or g['id']==args.group]
    if args.all and not args.include_large:
        groups=[g for g in groups if g['id']!='G4']
        print('Note: skipping G4 large archives; add --include-large to fetch.')
    report=[]
    for g in groups:
        if g['id']=='G4' and not (args.include_large or args.dry_run or args.list):
            print('G4 is large; add --include-large.');continue
        groupdir=args.output/g['id']
        for f in g['files']:
            dest=groupdir/f['filename']
            print(f"[{g['id']} {f['role']}] {f['filename']}\n  {f['url']}")
            if args.list or args.dry_run:continue
            groupdir.mkdir(parents=True,exist_ok=True)
            errors=[]
            if not dest.exists() or args.force:
                for url in (f['url'],f.get('fallback_url')):
                    if not url:continue
                    try:
                        retrieve(url,dest)
                        errors=[]
                        break
                    except Exception as exc:
                        errors.append(f'{url}: {exc}')
                if errors:
                    print('  FAILED:', ' | '.join(errors),file=sys.stderr)
                    report.append({'group':g['id'],'role':f['role'],'filename':f['filename'],'status':'ERROR','errors':errors})
                    continue
            info=file_metadata(dest)
            info.update({'group':g['id'],'role':f['role'],'source_url':f['url'],'release_date':f['release_date'],'downloaded_at_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'status':'OK'})
            report.append(info)
            print('  OK: ',info['size_bytes'],'bytes, SHA-256',info['sha256'])
    if report:
        args.output.mkdir(parents=True,exist_ok=True)
        (args.output/'download_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print('Saved:',args.output/'download_report.json')
    return 1 if any(r['status']=='ERROR' for r in report) else 0

if __name__=='__main__':sys.exit(main())
