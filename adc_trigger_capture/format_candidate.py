from pathlib import Path
import sys
sys.dont_write_bytecode=True
sys.path.insert(0,r'./local_inputs/readable-verilog-generator')
from scripts.python.quality.formatter_config import create_formatter_backend
root=Path(__file__).parent
backend=create_formatter_backend(overrides={
 'formatter':{'auto_fix_prefix':False,'sort_ports':False,'sort_params':False,'indent_style':'space','indent_size':4},
 'always_rules':{'auto_split':False,'single_reg_per_always':False},
 'state_machine':{'enforce_three_segment':False},
 'wire_assign_rules':{'rewrite_inline_wire_assign':False,'forbid_inline_wire_assign':False},
 'structure':{'enforce_region_order':False,'place_instances_last':False},
 'checks':{'naming':False,'prefix':False},
 'strict_mode':{'enabled':False,'fail_on_missing_clock_reset':False},
 'header':{'company_en':'','company_cn':'','engineer_en':'','engineer_cn':'','copyright_owner_en':'','copyright_owner_cn':'','developer_en':'','developer_cn':'','reviser_en':'','reviser_cn':''}
})
(root/'formatted').mkdir(exist_ok=True)
for p in (root/'rtl').glob('*.v'):
    try:
        output=backend.format_text(p.read_text(encoding='utf-8'),p)
        (root/'formatted'/p.name).write_text(output,encoding='utf-8')
        print(p.name,'formatted')
    except Exception as e:print(p.name,type(e).__name__,str(e))
