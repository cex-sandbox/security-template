# Injection Rules

## SQL-INJECTION — CRITICAL

**Trigger:** SQL query construction qua string concat / f-string / format / `%` với input L1.

**Data flow:** L1 (HTTP param, form, URL) → SQL string → execute.

**Skip:**
- Parameterized query (`?`, `%s`, `:name`, `$1`)
- ORM query builder (SQLAlchemy `.filter()`, Django `.filter()`)
- Identifier (table/column name) đã validate whitelist

**Bad:**
```python
user_id = request.args.get('id')
q = f"SELECT * FROM users WHERE id = '{user_id}'"
db.execute(q)
```

**Good:**
```python
user_id = request.args.get('id')
db.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

---

## COMMAND-INJECTION — CRITICAL

**Trigger:** `subprocess.run/call/Popen(..., shell=True)`, `os.system`, `os.popen` với input L1.

**Data flow:** L1 → shell string → execute.

**Bad:**
```python
filename = request.args.get('file')
subprocess.run(f"cat {filename}", shell=True)
```

**Good:**
```python
filename = request.args.get('file')
# Validate filename
if not re.match(r'^[a-zA-Z0-9_.-]+$', filename):
    abort(400)
subprocess.run(["cat", filename], shell=False, check=True)
```

---

## INSECURE-DESERIALIZATION — CRITICAL

**Trigger:** `pickle.loads`, `yaml.load` (không SafeLoader), `marshal.loads`, `eval`, `exec` với input L1.

**Data flow:** L1 → deserialize → arbitrary code execution.

**Bad:**
```python
data = pickle.loads(request.data)
config = yaml.load(open('config.yml'))  # yaml.load = unsafe
result = eval(request.args.get('expr'))
```

**Good:**
```python
data = json.loads(request.data)
config = yaml.safe_load(open('config.yml'))
# eval không có lựa chọn an toàn — refactor logic
```

---

## XSS — HIGH

**Trigger:** User input L1 → HTML response **không escape**.

**Data flow:** L1 (form, query) → template render hoặc string concat → HTML output.

**Skip:**
- Template engine auto-escape (Jinja2 default, React JSX default)
- Explicit escape (`html.escape`, `markupsafe.escape`)

**Bad (Flask):**
```python
@app.route('/search')
def search():
    q = request.args.get('q')
    return f"<h1>Results for {q}</h1>"
```

**Good:**
```python
from markupsafe import escape
return f"<h1>Results for {escape(q)}</h1>"
# Hoặc dùng Jinja2 template (auto-escape)
```

---

## SSRF — HIGH

**Trigger:** `requests.get(url)`, `urllib.request.urlopen(url)` với URL từ L1.

**Data flow:** L1 (user-provided URL) → HTTP fetch → có thể truy cập internal services (`169.254.169.254`, `localhost`, internal IPs).

**Bad:**
```python
url = request.args.get('image_url')
resp = requests.get(url)
```

**Good:**
```python
url = request.args.get('image_url')
parsed = urlparse(url)
# Whitelist scheme + host
if parsed.scheme not in ('http', 'https'):
    abort(400)
if not is_public_ip(socket.gethostbyname(parsed.hostname)):
    abort(400)
resp = requests.get(url, timeout=5, allow_redirects=False)
```
