import os
import oracledb
from flask import Flask, render_template, request, redirect, url_for, flash, g

app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev_key')

# db credentials, defaults match docker-compose
DB_USER = os.environ.get('DB_USER', 'system')
DB_PASS = os.environ.get('DB_PASS', 'password123')
DB_DSN  = os.environ.get('DB_DSN', 'localhost:1521/XE')


def get_db():
    """one connection per request, stored in flask.g"""
    if '_database' not in g:
        g._database = oracledb.connect(user=DB_USER, password=DB_PASS, dsn=DB_DSN)
    return g._database


@app.teardown_appcontext
def close_db(exc):
    db = g.pop('_database', None)
    if db:
        db.close()


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/conferences')
def list_conferences():
    try:
        cur = get_db().cursor()
        cur.execute("SELECT acronym, name, location, homepage_url FROM Conference ORDER BY name")
        rows = cur.fetchall()
        cur.close()
    except oracledb.DatabaseError as e:
        flash(f"Database error: {e}", "danger")
        rows = []
    return render_template('conferences.html', conferences=rows)


@app.route('/conference/<acronym>/accepted-articles')
def accepted_articles(acronym):
    """OP4 -- accepted articles for a conference"""
    try:
        cur = get_db().cursor()
        ref = cur.var(oracledb.CURSOR)
        cur.callproc('prc_get_accepted_articles', [acronym, ref])
        result_cursor = ref.getvalue()
        rows = result_cursor.fetchall() if result_cursor else []
        cur.close()
    except oracledb.DatabaseError as e:
        flash(f"Database error: {e}", "danger")
        rows = []
    return render_template('accepted_articles.html', acronym=acronym, articles=rows)


@app.route('/submit-review', methods=['GET', 'POST'])
def submit_review():
    """OP3 -- submit a peer review"""
    if request.method == 'POST':
        code = request.form['review_code']
        orig = int(request.form['originality'])
        sig  = int(request.form['significance'])
        qual = int(request.form['quality'])
        comments = request.form.get('comments', '')
        content  = request.form.get('content', '')

        cur = get_db().cursor()

        cur.execute("SELECT 1 FROM Review WHERE code = :c", {'c': code})
        if not cur.fetchone():
            flash(f"Review code '{code}' not found.", "danger")
            cur.close()
            return redirect(url_for('submit_review'))

        try:
            cur.callproc('prc_add_review', [code, orig, sig, qual, comments, content])
            get_db().commit()
            score = round((orig + sig + qual) / 3)
            flash(f"Review submitted! Global score: {score}.", "success")
        except oracledb.DatabaseError as e:
            flash(f"DB error: {e}", "danger")
        finally:
            cur.close()

        return redirect(url_for('submit_review'))

    # GET: load reviews for a reviewer if provided
    reviewer_code = request.args.get('reviewer', '').strip()
    reviews = []
    if reviewer_code:
        try:
            cur = get_db().cursor()
            cur.execute(
                "SELECT r.code, a.title FROM Review r "
                "JOIN Article a ON r.article_id = a.article_id "
                "WHERE r.reviewer_code = :rc ORDER BY a.title",
                {'rc': reviewer_code}
            )
            reviews = cur.fetchall()
            cur.close()
            if not reviews:
                flash(f"No reviews found for reviewer '{reviewer_code}'.", "danger")
        except oracledb.DatabaseError as e:
            flash(f"DB error: {e}", "danger")

    return render_template('submit_review.html', reviewer_code=reviewer_code, reviews=reviews)


@app.route('/reviewer/<code>/assignments')
def reviewer_assignments(code):
    """OP2 -- articles assigned to a reviewer"""
    try:
        cur = get_db().cursor()
        ref = cur.var(oracledb.CURSOR)
        cur.callproc('prc_get_reviewer_assignments', [code, ref])
        result_cursor = ref.getvalue()
        rows = result_cursor.fetchall() if result_cursor else []
        cur.close()
    except oracledb.DatabaseError as e:
        flash(f"Database error: {e}", "danger")
        rows = []
    return render_template('assignments.html', assignments=rows, reviewer_code=code)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
