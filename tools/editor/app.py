#!/usr/bin/env python3
"""
app.py — local Kalimat editor (furuq review + verified toggle + export).

Runs ONLY on your machine. Not part of the shipped app. It edits the master DB
and exports the public assets/db/kalimat.db (unverified furuq stripped).

Setup:
    pip install flask
    python3 app.py
    # open http://127.0.0.1:5000

Point it at a different master with:  KALIMAT_MASTER=/path/to/master.db python3 app.py
"""
import os
from flask import Flask, request, redirect, url_for, render_template_string, flash

import store

if os.environ.get("KALIMAT_MASTER"):
    store.MASTER = os.environ["KALIMAT_MASTER"]

app = Flask(__name__)
app.secret_key = "kalimat-editor-local"

BASE = """
<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>محرّر كلمات</title>
<style>
  :root{--teal:#0F5B52;--brass:#B07C2E;--paper:#F4EEE1;--ink:#2A251C;--card:#FBF7EE;--line:#E7DEC9}
  *{box-sizing:border-box} body{margin:0;font-family:system-ui,'Segoe UI',Tahoma,sans-serif;
    background:var(--paper);color:var(--ink)}
  header{background:var(--teal);color:var(--paper);padding:16px 22px;display:flex;
    align-items:center;justify-content:space-between}
  header b{font-size:20px} .wrap{max-width:900px;margin:0 auto;padding:20px}
  .pill{display:inline-block;padding:3px 10px;border-radius:999px;font-size:12px;font-weight:700}
  .ok{background:#E4EFEC;color:var(--teal)} .pending{background:#F2E4C6;color:#8A5E1E}
  .stats{display:flex;gap:10px;margin:14px 0}
  .stats div{background:var(--card);border:1px solid var(--line);border-radius:12px;
    padding:10px 16px;font-size:14px}
  .filters{display:flex;gap:8px;margin:12px 0;flex-wrap:wrap}
  a.btn,button{font:inherit;border:1px solid var(--line);background:var(--card);color:var(--ink);
    padding:8px 14px;border-radius:10px;cursor:pointer;text-decoration:none}
  a.btn.active{background:var(--teal);color:var(--paper);border-color:var(--teal)}
  button.primary{background:var(--teal);color:var(--paper);border-color:var(--teal);font-weight:700}
  button.export{background:var(--brass);color:#2A251C;border-color:var(--brass);font-weight:700}
  .row{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:14px;
    margin-bottom:10px;display:flex;align-items:center;justify-content:space-between;gap:12px}
  .pair{font-size:20px;font-weight:700} .muted{color:#6B6353;font-size:13px;margin-top:4px}
  .flash{background:#E4EFEC;border:1px solid #CFE2DC;color:var(--teal);padding:12px 16px;
    border-radius:10px;margin-bottom:14px}
  label{display:block;font-size:13px;font-weight:700;color:var(--teal);margin:12px 0 4px}
  input,textarea{width:100%;padding:10px;border:1px solid var(--line);border-radius:8px;
    font:inherit;background:#fff} textarea{min-height:90px}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  form.inline{display:inline}
</style></head><body>
<header><b>محرّر كلمات · مراجعة الفروق</b>
  <form class="inline" method="post" action="{{ url_for('export') }}">
    <button class="export" onclick="return confirm('تصدير قاعدة التطبيق؟ سيُحذف كل غير المحقَّق.')">
      تصدير kalimat.db</button>
  </form>
</header>
<div class="wrap">
{% with msgs = get_flashed_messages() %}{% for m in msgs %}<div class="flash">{{ m }}</div>{% endfor %}{% endwith %}
{{ body|safe }}
</div></body></html>
"""

LIST = """
<div class="stats">
  <div>المحقَّق: <b>{{ s.verified }}</b></div>
  <div>بانتظار المراجعة: <b>{{ s.unverified }}</b></div>
  <div>الإجمالي: <b>{{ s.total }}</b></div>
</div>
<div class="filters">
  <a class="btn {{ 'active' if status=='all' else '' }}" href="?status=all">الكل</a>
  <a class="btn {{ 'active' if status=='unverified' else '' }}" href="?status=unverified">بانتظار المراجعة</a>
  <a class="btn {{ 'active' if status=='verified' else '' }}" href="?status=verified">المحقَّق</a>
</div>
{% for f in rows %}
<div class="row">
  <div>
    <div class="pair">{{ f.root_a }} × {{ f.root_b }}
      {% if f.verified %}<span class="pill ok">محقَّق</span>
      {% else %}<span class="pill pending">بانتظار</span>{% endif %}
    </div>
    <div class="muted">{{ (f.difference or '')[:90] }}</div>
  </div>
  <div style="display:flex;gap:8px">
    <a class="btn" href="{{ url_for('edit', fid=f.furuq_id) }}">تحرير</a>
    <form class="inline" method="post" action="{{ url_for('verify', fid=f.furuq_id) }}">
      <input type="hidden" name="value" value="{{ 0 if f.verified else 1 }}">
      <button class="{{ '' if f.verified else 'primary' }}">
        {{ 'إلغاء التحقّق' if f.verified else 'اعتماد ✓' }}</button>
    </form>
  </div>
</div>
{% else %}<p class="muted">لا توجد عناصر.</p>{% endfor %}
"""

EDIT = """
<p><a class="btn" href="{{ url_for('index') }}">→ رجوع</a></p>
<h2>{{ f.root_a }} × {{ f.root_b }}
  {% if f.verified %}<span class="pill ok">محقَّق</span>{% else %}<span class="pill pending">بانتظار</span>{% endif %}
</h2>
<form method="post">
  <div class="grid">
    <div><label>الجذر الأول</label><input name="root_a" value="{{ f.root_a or '' }}"></div>
    <div><label>الجذر الثاني</label><input name="root_b" value="{{ f.root_b or '' }}"></div>
    <div><label>المعنى المحوري (أ)</label><input name="maqayis_a" value="{{ f.maqayis_a or '' }}"></div>
    <div><label>المعنى المحوري (ب)</label><input name="maqayis_b" value="{{ f.maqayis_b or '' }}"></div>
    <div><label>الدلالة القرآنية (أ)</label><input name="quran_a" value="{{ f.quran_a or '' }}"></div>
    <div><label>الدلالة القرآنية (ب)</label><input name="quran_b" value="{{ f.quran_b or '' }}"></div>
    <div><label>عدد المواضع (أ)</label><input name="count_a" value="{{ f.count_a or '' }}"></div>
    <div><label>عدد المواضع (ب)</label><input name="count_b" value="{{ f.count_b or '' }}"></div>
    <div><label>المقابل السامي (أ)</label><input name="semitic_a" value="{{ f.semitic_a or '' }}"></div>
    <div><label>المقابل السامي (ب)</label><input name="semitic_b" value="{{ f.semitic_b or '' }}"></div>
  </div>
  <label>الفرق</label><textarea name="difference">{{ f.difference or '' }}</textarea>
  <label>المصدر</label><input name="source" value="{{ f.source or '' }}">
  <div style="margin-top:16px;display:flex;gap:8px">
    <button class="primary" type="submit">حفظ</button>
  </div>
</form>
"""


@app.get("/")
def index():
    status = request.args.get("status", "all")
    q = request.args.get("q", "")
    rows = store.list_furuq(status=status, q=q)
    body = render_template_string(LIST, rows=rows, s=store.stats(), status=status)
    return render_template_string(BASE, body=body)


@app.route("/edit/<int:fid>", methods=["GET", "POST"])
def edit(fid):
    if request.method == "POST":
        store.update_furuq(fid, request.form.to_dict())
        flash("حُفظت التعديلات.")
        return redirect(url_for("edit", fid=fid))
    f = store.get_furuq(fid)
    if not f:
        return redirect(url_for("index"))
    body = render_template_string(EDIT, f=f)
    return render_template_string(BASE, body=body)


@app.post("/verify/<int:fid>")
def verify(fid):
    store.set_verified(fid, request.form.get("value") == "1")
    return redirect(request.referrer or url_for("index"))


@app.post("/export")
def export():
    res = store.export_app_db(version=None)
    flash(f"تم التصدير → {res['out']} · محقَّق: {res['verified_kept']} · "
          f"حُذف غير المحقَّق: {res['unverified_stripped']}")
    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(debug=True)
