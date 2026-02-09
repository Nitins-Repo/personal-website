import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
resume_txt = ROOT / 'resume.txt'

def read_lines():
    text = resume_txt.read_text(encoding='utf-8', errors='ignore')
    lines = [l.rstrip() for l in text.splitlines()]
    return lines

def find_email(lines):
    rx = re.compile(r'[\w\.-]+@[\w\.-]+\.[A-Za-z]{2,}')
    for line in lines:
        m = rx.search(line)
        if m:
            return m.group(0)
    return ''

def find_phone(lines):
    rx = re.compile(r'\+?\d[\d\-\s\(\)]{6,}\d')
    for line in lines:
        m = rx.search(line)
        if m:
            return m.group(0)
    return ''

HEADERS = ['summary','profile','about','experience','work experience','education','skills','projects','contact','certifications']

def locate_sections(lines):
    idx = {}
    for i,line in enumerate(lines):
        s = line.strip().lower().rstrip(':')
        if s in HEADERS:
            idx[s]=i
    # also detect ALL-CAP headings
    for i,line in enumerate(lines):
        if len(line.strip())>0 and line.strip()==line.strip().upper() and len(line.strip())<60:
            s=line.strip().lower().rstrip(':')
            if s not in idx:
                idx[s]=i
    return idx

def section_text(lines, start, end):
    return '\n'.join([l for l in lines[start:end] if l.strip()])

def extract():
    lines = read_lines()
    email = find_email(lines)
    phone = find_phone(lines)
    idx = locate_sections(lines)

    # summary
    summary=''
    for key in ('summary','profile','about'):
        if key in idx:
            starts=idx[key]+1
            # find next section index
            next_idx=min([v for k,v in idx.items() if v>idx[key]]+[len(lines)])
            summary=section_text(lines, starts, next_idx).strip()
            break
    if not summary:
        # fallback: first 8 non-empty lines
        nonempty=[l for l in lines if l.strip()]
        summary=' '.join(nonempty[:8])

    # skills
    skills=''
    if 'skills' in idx:
        starts=idx['skills']+1
        next_idx=min([v for k,v in idx.items() if v>idx['skills']]+[len(lines)])
        skills=section_text(lines, starts, next_idx)
        # split by commas or newlines
        items=[s.strip('-• ') for s in re.split('[,\n]', skills) if s.strip()]
    else:
        items=[]

    return {
        'email': email,
        'phone': phone,
        'summary': summary,
        'skills': items,
    }

def replace_main(file_path, new_inner_html):
    s = file_path.read_text(encoding='utf-8')
    new = re.sub(r'(<main[^>]*>)(.*?)(</main>)', lambda m: m.group(1)+new_inner_html+m.group(3), s, flags=re.S)
    file_path.write_text(new, encoding='utf-8')

def update_site(data):
    # About
    about_file = ROOT / 'about.html'
    about_html = f"<h1>About Me</h1>\n      <p>{data['summary']}</p>\n"
    replace_main(about_file, about_html)

    # Skills
    skills_file = ROOT / 'skills.html'
    skills_list = '\n'.join([f"<li>{s}</li>" for s in data['skills']]) if data['skills'] else '<li>—</li>'
    skills_html = f"<h1>Skills</h1>\n      <ul>\n      {skills_list}\n      </ul>\n"
    replace_main(skills_file, skills_html)

    # Contact
    contact_file = ROOT / 'contact.html'
    contact_html = f"<h1>Contact</h1>\n      <p>Reach out via email: <a href=\"mailto:{data['email']}\">{data['email']}</a>" \
                   + (f"<br>Phone: {data['phone']}" if data['phone'] else '') + "</p>\n"
    replace_main(contact_file, contact_html)

    print('Updated about.html, skills.html, contact.html')

if __name__=='__main__':
    data=extract()
    print('Found email:', data['email'])
    print('Found phone:', data['phone'])
    print('Summary preview:\n', data['summary'][:400])
    print('Skills count:', len(data['skills']))
    update_site(data)
