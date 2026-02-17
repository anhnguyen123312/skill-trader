#!/usr/bin/env python3
"""Parse MT5 Strategy Tester HTML Report -> single Markdown file.

Extracts ALL data from the UTF-16 encoded HTML report:
- Settings (expert, symbol, period, inputs, deposit, leverage, etc.)
- Results (all statistics, drawdown, ratios, trade counts, etc.)
- Correlation & holding time stats
- Orders table (every order with SL/TP)
- Deals table (every deal with commission/swap/profit)

Usage:
    python3 parse_report.py <report.htm> [--output-dir <dir>]

Output:
    <dir>/<ea>_report.md   - Single Markdown file with everything
"""

import sys
import os
import re
from pathlib import Path
from datetime import datetime


def read_report(path):
    """Read MT5 HTML report handling UTF-16 encoding."""
    with open(path, 'rb') as f:
        raw = f.read()
    for enc in ['utf-16', 'utf-16-le', 'utf-8']:
        try:
            return raw.decode(enc)
        except (UnicodeDecodeError, UnicodeError):
            continue
    return raw.decode('utf-8', errors='replace')


def strip_tags(html):
    """Remove HTML tags and clean whitespace."""
    text = re.sub(r'<[^>]+>', '', html)
    text = text.replace('&nbsp;', ' ').replace('&amp;', '&')
    text = text.replace('&lt;', '<').replace('&gt;', '>')
    return text.strip()


def parse_settings(html):
    """Parse the Settings section."""
    settings = {}
    patterns = [
        ('Expert', r'Expert:</td>\s*<td[^>]*><b>(.*?)</b>'),
        ('Symbol', r'Symbol:</td>\s*<td[^>]*><b>(.*?)</b>'),
        ('Period', r'Period:</td>\s*<td[^>]*><b>(.*?)</b>'),
        ('Inputs', r'Inputs:</td>\s*<td[^>]*><b>(.*?)</b>'),
        ('Company', r'Company:</td>\s*<td[^>]*><b>(.*?)</b>'),
        ('Currency', r'Currency:</td>\s*<td[^>]*><b>(.*?)</b>'),
        ('Initial Deposit', r'Initial Deposit:</td>\s*<td[^>]*><b>(.*?)</b>'),
        ('Leverage', r'Leverage:</td>\s*<td[^>]*><b>(.*?)</b>'),
    ]
    for name, pattern in patterns:
        m = re.search(pattern, html, re.DOTALL)
        if m:
            settings[name] = strip_tags(m.group(1))
    m = re.search(r'<b>([^<]*Build\s+\d+[^<]*)</b>', html)
    if m:
        settings['Broker Build'] = strip_tags(m.group(1))
    return settings


def parse_statistics(html):
    """Parse ALL statistics from the Results section."""
    stats = {}
    # Match all label:value pairs (handles colspan variants)
    for pattern in [
        r'<td[^>]*>([^<]*?):</td>\s*<td[^>]*><b>(.*?)</b></td>',
        r'<td[^>]*colspan="3"[^>]*>([^<]*?):</td>\s*<td[^>]*><b>(.*?)</b></td>',
        r'<td[^>]*colspan="3"[^>]*>([^<]*?):</td>\s*<td[^>]*colspan="2"[^>]*><b>(.*?)</b></td>',
    ]:
        for m in re.finditer(pattern, html, re.DOTALL):
            label = strip_tags(m.group(1)).strip()
            value = strip_tags(m.group(2)).strip()
            if label:
                stats[label] = value
    return stats


def parse_table(html, section_name):
    """Parse a table section (Orders or Deals) into header + rows."""
    section_match = re.search(
        rf'<b>{section_name}</b>(.*?)(?:</table>)', html, re.DOTALL
    )
    if not section_match:
        return [], []

    table_html = section_match.group(1)

    headers = []
    header_match = re.search(r'bgcolor="#E5F0FC"(.*?)</tr>', table_html, re.DOTALL)
    if header_match:
        headers = [strip_tags(h).strip() for h in re.findall(r'<b>(.*?)</b>', header_match.group(1))]

    rows = []
    for row_match in re.finditer(r'<tr[^>]*>(.*?)</tr>', table_html, re.DOTALL):
        row_html = row_match.group(1)
        if 'E5F0FC' in row_html or 'height: 10px' in row_html or 'height:10px' in row_html or '<div' in row_html:
            continue
        cells = []
        for cell_match in re.finditer(r'<td[^>]*>(.*?)</td>', row_html, re.DOTALL):
            cell_html = cell_match.group(1)
            bold = re.search(r'<b>(.*?)</b>', cell_html, re.DOTALL)
            cells.append(strip_tags(bold.group(1)).strip() if bold else strip_tags(cell_html).strip())
        non_empty = sum(1 for c in cells if c)
        if cells and non_empty >= 3:
            if headers and cells[:len(headers)] == headers:
                continue
            rows.append(cells)

    return headers, rows


def md_table(headers, rows):
    """Generate a Markdown table string."""
    if not headers or not rows:
        return '*No data*\n'

    lines = []
    # Header
    lines.append('| ' + ' | '.join(headers) + ' |')
    lines.append('| ' + ' | '.join(['---'] * len(headers)) + ' |')
    # Rows - pad to header length
    for row in rows:
        padded = row + [''] * (len(headers) - len(row))  # pad short rows
        lines.append('| ' + ' | '.join(padded[:len(headers)]) + ' |')
    return '\n'.join(lines) + '\n'


def build_markdown(settings, stats, orders_headers, orders_rows, deals_headers, deals_rows):
    """Build the complete Markdown report."""
    md = []

    ea = settings.get('Expert', 'Unknown')
    symbol = settings.get('Symbol', '')
    period = settings.get('Period', '')

    md.append(f'# Strategy Tester Report: {ea}')
    md.append('')
    md.append(f'> Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}')
    md.append('')

    # --- Settings ---
    md.append('## Settings')
    md.append('')
    md.append('| Parameter | Value |')
    md.append('| --- | --- |')
    for k, v in settings.items():
        if v:
            md.append(f'| {k} | {v} |')
    md.append('')

    # --- Performance ---
    perf_keys = [
        'History Quality', 'Bars', 'Ticks', 'Symbols',
        'Total Net Profit', 'Gross Profit', 'Gross Loss',
        'Profit Factor', 'Expected Payoff', 'Recovery Factor',
        'Sharpe Ratio', 'Z-Score', 'Margin Level',
        'AHPR', 'GHPR', 'LR Correlation', 'LR Standard Error',
        'OnTester result',
    ]
    md.append('## Performance')
    md.append('')
    md.append('| Metric | Value |')
    md.append('| --- | --- |')
    for k in perf_keys:
        if k in stats:
            md.append(f'| {k} | {stats[k]} |')
    md.append('')

    # --- Drawdown ---
    dd_keys = [
        'Balance Drawdown Absolute', 'Balance Drawdown Maximal', 'Balance Drawdown Relative',
        'Equity Drawdown Absolute', 'Equity Drawdown Maximal', 'Equity Drawdown Relative',
    ]
    md.append('## Drawdown')
    md.append('')
    md.append('| Metric | Value |')
    md.append('| --- | --- |')
    for k in dd_keys:
        if k in stats:
            md.append(f'| {k} | {stats[k]} |')
    md.append('')

    # --- Trades ---
    trade_keys = [
        'Total Trades', 'Total Deals',
        'Short Trades (won %)', 'Long Trades (won %)',
        'Profit Trades (% of total)', 'Loss Trades (% of total)',
        'Largest profit trade', 'Largest loss trade',
        'Average profit trade', 'Average loss trade',
        'Maximum consecutive wins ($)', 'Maximum consecutive losses ($)',
        'Maximal consecutive profit (count)', 'Maximal consecutive loss (count)',
        'Average consecutive wins', 'Average consecutive losses',
    ]
    md.append('## Trades')
    md.append('')
    md.append('| Metric | Value |')
    md.append('| --- | --- |')
    for k in trade_keys:
        if k in stats:
            md.append(f'| {k} | {stats[k]} |')
    md.append('')

    # --- Correlation & Holding ---
    corr_keys = [
        'Correlation (Profits,MFE)', 'Correlation (Profits,MAE)', 'Correlation (MFE,MAE)',
        'Correlation (Profits, MFE)', 'Correlation (Profits, MAE)', 'Correlation (MFE, MAE)',
    ]
    hold_keys = [
        'Minimal position holding time', 'Maximal position holding time',
        'Average position holding time',
    ]
    md.append('## Correlation & Position Holding')
    md.append('')
    md.append('| Metric | Value |')
    md.append('| --- | --- |')
    printed = set()
    for k in corr_keys + hold_keys:
        if k in stats and k not in printed:
            md.append(f'| {k} | {stats[k]} |')
            printed.add(k)
    md.append('')

    # --- Any remaining stats ---
    all_grouped = set(perf_keys + dd_keys + trade_keys + corr_keys + hold_keys)
    remaining = [(k, v) for k, v in stats.items() if k not in all_grouped and v]
    if remaining:
        md.append('## Other Metrics')
        md.append('')
        md.append('| Metric | Value |')
        md.append('| --- | --- |')
        for k, v in remaining:
            md.append(f'| {k} | {v} |')
        md.append('')

    # --- Deals ---
    md.append('## Deals')
    md.append('')
    md.append(f'Total: {len(deals_rows)} deals')
    md.append('')
    md.append(md_table(deals_headers, deals_rows))

    # --- Orders ---
    md.append('## Orders')
    md.append('')
    md.append(f'Total: {len(orders_rows)} orders')
    md.append('')
    md.append(md_table(orders_headers, orders_rows))

    return '\n'.join(md)


def main():
    if len(sys.argv) < 2:
        print("Usage: parse_report.py <report.htm> [--output-dir <dir>]")
        sys.exit(1)

    report_path = sys.argv[1]
    output_dir = '.'

    if '--output-dir' in sys.argv:
        idx = sys.argv.index('--output-dir')
        if idx + 1 < len(sys.argv):
            output_dir = sys.argv[idx + 1]

    if not os.path.exists(report_path):
        print(f"ERROR: Report not found: {report_path}")
        sys.exit(1)

    html = read_report(report_path)

    # Warn if report is empty
    total_trades_match = re.search(r'Total Trades:.*?<b>(\d+)</b>', html, re.DOTALL)
    if total_trades_match and total_trades_match.group(1) == '0':
        deposit_match = re.search(r'Initial Deposit:.*?<b>([^<]+)</b>', html, re.DOTALL)
        if deposit_match and strip_tags(deposit_match.group(1)).strip() == '0':
            print("WARNING: Report appears empty (all zeros). Backtest may need re-run.")

    settings = parse_settings(html)
    stats = parse_statistics(html)

    # Remove settings keys that leaked into stats
    settings_keys = set(settings.keys())
    stats = {k: v for k, v in stats.items() if k not in settings_keys}

    orders_headers, orders_rows = parse_table(html, 'Orders')
    deals_headers, deals_rows = parse_table(html, 'Deals')

    # Derive output filename
    ea_name = settings.get('Expert', '')
    if not ea_name:
        ea_name = Path(report_path).stem.replace('_Report', '')
    ea_name_safe = re.sub(r'[^\w\-]', '_', ea_name)

    os.makedirs(output_dir, exist_ok=True)

    # Build and write single MD file
    md_content = build_markdown(settings, stats, orders_headers, orders_rows, deals_headers, deals_rows)
    md_path = os.path.join(output_dir, f"{ea_name_safe}_report.md")
    with open(md_path, 'w') as f:
        f.write(md_content)

    # Print summary to stdout
    print(f"Parsed: {len(stats)} metrics, {len(deals_rows)} deals, {len(orders_rows)} orders")
    print(f"Output: {md_path}")


if __name__ == '__main__':
    main()
