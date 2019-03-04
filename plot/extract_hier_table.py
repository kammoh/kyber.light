import numpy as np
import matplotlib.pyplot as plt
import pathlib
import re
from jinja2 import Template, Environment, FileSystemLoader, select_autoescape
import os

from pprint import pprint

THIS_DIR = os.path.dirname(os.path.abspath(__file__))

class ParseException(Exception):
    pass


class Table():
    def __init__(self, name, header, data):
        self.name = name
        self.header = header
        self.data = data

## FIXME VERY BAD MESSY CODE WILL DEFINITLY BREAK TODO ******


def read_until(rf, pattern, g=1, anti_pattern=None, max_len=None):
    p = re.compile(pattern)
    if anti_pattern:
        ap = re.compile(anti_pattern)
    else:
        ap = None
    ret = []
    while True:
        line = rf.readline()
        if not line:
            return ret
        line = line.strip()
        if ap and len(ret) > 0 and ap.match(line):
            return ret
        l = []
        for i in p.finditer(line):
            l.append(i.group(g))
        if len(l) > 0:
            ret.append(l)
            if max_len and len(ret) >= max_len:
                return ret
        elif len(ret) > 0:
            return ret


def lastrun_utilization(path):
    tables={}
    with pathlib.Path(path).open() as rf:
        while True:
            # try:
            table_name = read_until(rf, r'^\d+\.\s+(\w.*)', max_len=1)
            if len(table_name) == 0:
                break
            table_name = table_name[0][0]
            headers = read_until(rf, r'\s+([^\|]*)\|', max_len=1)
            if len(headers) == 0:
                break
            header = headers[0]

            data_rows = read_until(rf, r'([^\|]+)\s*\|', anti_pattern=r'^(\+[\-]+)+\+')
            
            prev_indent = None
            for i in range(0, len(data_rows)):
                rec_name = data_rows[i][0]
                rec_name1 = rec_name if i == 0 else data_rows[i][1]
                data_rows[i][0] = []
                num_lead_space = len(rec_name) - len(rec_name.lstrip())
                if prev_indent == None:
                    pass
                else:
                    if num_lead_space > prev_indent:
                        data_rows[i][0] = list(data_rows[i-1][0] )
                    elif num_lead_space < prev_indent:
                        data_rows[i][0] = list(data_rows[i-1][0][:-2])
                    else: # ==
                        data_rows[i][0] = list(data_rows[i-1][0][:-1])
                data_rows[i][0].append(rec_name1.strip())
                for j in range(1, len(data_rows[i])):
                    data_rows[i][j] = data_rows[i][j].strip()
                    try:
                        data_rows[i][j] = int(data_rows[i][j])
                    except:
                        pass
                prev_indent = num_lead_space

            tables[table_name] = Table(table_name, header, data_rows)
    return tables  


tables = lastrun_utilization('synth.Vivado.cpa_enc.2019-02-25.02.23.54.594394/reports/post_route_util_hierarchical.rpt')
table = tables['Utilization by Hierarchy']

fig, ax = plt.subplots()
ax.axis('equal')
width = 0.3

cm = plt.get_cmap("tab20c")

q = {}
levels = 0

print(f"{table.header}")

from typing import List

class Tree:
    def __init__(self, root, children: List, value):
        self.root = root
        self.children = children
        self.value = value
    
    def add(self, hier, value):
        if len(hier) > 0:
            for child in self.children:
                if child.root == hier[0]:
                    child.add(hier[1:], value)
                    break
        else:
            self.children.append(Tree(hier[0], [], value))




# tree=Tree('root', [], None)

data_dict = {}
data2={}

def add_to_dict(path, size, dd):
    if len(path) <= 0:
        return
    if 'name' not in dd:
        dd['name'] = path[0]
    assert dd['name'] == path[0]
    if len(path) == 1:
        dd['value'] = size
        return
    if 'children' not in dd:
        dd['children'] = []
        if 'value' in dd:
            dd.pop('value')
    for child_dict in dd['children']:
        if path[1] == child_dict['name']:
            add_to_dict(path[1:], size, child_dict)
            return
    child_dict = {'name': path[1]}
    dd['children'].append(child_dict)
    add_to_dict(path[1:], size, child_dict)


for row in table.data:
    # print(f"{'/'.join(row[0])} {row[2:]}")
    # tree.add(row[0], row[2])
    add_to_dict(row[0], row[2], data_dict) # LUT
    add_to_dict(row[0], row[6], data2) # FF
    
    # print(f'q[{l}] = {q[l]}' )


j2_env = Environment(loader=FileSystemLoader(THIS_DIR), trim_blocks=True, lstrip_blocks=True)

run_path = pathlib.Path(".")
html_file_relpath = pathlib.Path("report.html")

scripts = []
for script_file in ["sunburst.js"]:
    scripts.append(pathlib.Path(THIS_DIR).joinpath(script_file).open(mode='r').read())

html_template = j2_env.get_template('plot.template.html')
html = html_template.render(data1=data_dict, data2=data2, scripts=scripts)


with run_path.joinpath(html_file_relpath).open(mode='w') as hf:
    hf.write(html)
# def sunburst(nodes, total=np.pi * 2, offset=0, level=0, ax=None):
#     ax = ax or plt.subplot(111, projection='polar')

#     if level == 0 and len(nodes) == 1:
#         label, value, subnodes = nodes[0]
#         ax.bar([0], [0.5], [np.pi * 2])
#         ax.text(0, 0, label, ha='center', va='center')
#         sunburst(subnodes, total=value, level=level + 1, ax=ax)
#     elif nodes:
#         d = np.pi * 2 / total
#         labels = []
#         widths = []
#         local_offset = offset
#         for label, value, subnodes in nodes:
#             labels.append(label)
#             widths.append(value * d)
#             sunburst(subnodes, total=total, offset=local_offset,
#                      level=level + 1, ax=ax)
#             local_offset += value
#         values = np.cumsum([offset * d] + widths[:-1])
#         heights = [1] * len(nodes)
#         bottoms = np.zeros(len(nodes)) + level - 0.5
#         rects = ax.bar(values, heights, widths, bottoms, linewidth=1,
#                        edgecolor='white', align='edge')
#         for rect, label in zip(rects, labels):
#             x = rect.get_x() + rect.get_width() / 2
#             y = rect.get_y() + rect.get_height() / 2
#             rotation = (90 + (360 - np.degrees(x) % 180)) % 360
#             ax.text(x, y, label, rotation=rotation, ha='center', va='center',
#                     fontsize='xx-small', fontstretch='ultra-condensed',)

#     if level == 0:
#         ax.set_theta_direction(-1)
#         ax.set_theta_zero_location('N')
#         ax.set_axis_off()


# data = [
#     ('/', 100, [
#         ('home', 70, [
#             ('Images', 40, []),
#             ('Videos', 20, []),
#             ('Documents', 5, []),
#         ]),
#         ('usr', 15, [
#             ('src', 6, [
#                 ('linux-headers', 4, []),
#                 ('virtualbox', 1, []),

#             ]),
#             ('lib', 4, []),
#             ('share', 2, []),
#             ('bin', 1, []),
#             ('local', 1, []),
#             ('include', 1, []),
#         ]),
#     ]),
# ]

# sunburst(data)

# plt.show()
