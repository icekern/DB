-- index analysis: explain plan before and after adding indexes
-- oracle auto-creates indexes for PK and UNIQUE, but NOT for FK columns

SET SERVEROUTPUT ON;

-- before indexes

-- Q1: count reviews by article_id (used by BR1, BR5, BR6, BR13)
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_BEFORE' FOR
    SELECT COUNT(*) FROM Review WHERE article_id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1_BEFORE', 'BASIC'));

-- Q2: find reviews by reviewer (used by OP2)
EXPLAIN PLAN SET STATEMENT_ID = 'Q2_BEFORE' FOR
    SELECT rev.article_id
    FROM Review rev
    WHERE rev.reviewer_code = 'ORG_1_1';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q2_BEFORE', 'BASIC'));

-- Q3: accepted articles for a conference (used by OP4)
EXPLAIN PLAN SET STATEMENT_ID = 'Q3_BEFORE' FOR
    SELECT art.category, art.title, art.avg_global_score
    FROM Article art
    WHERE art.conference_acronym = 'CONF_1'
      AND art.status = 'accepted'
    ORDER BY art.category, art.title;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q3_BEFORE', 'BASIC'));

-- Q4: count members by conference (used by BR9)
EXPLAIN PLAN SET STATEMENT_ID = 'Q4_BEFORE' FOR
    SELECT COUNT(*) FROM Membership
    WHERE conference_acronym = 'CONF_1';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q4_BEFORE', 'BASIC'));
-- conference_acronym is 2nd col in PK, oracle cant use the PK index here


-- create indexes

-- review(article_id): most critical, used by 4 triggers
CREATE INDEX idx_review_article_id
    ON Review(article_id);

-- review(reviewer_code): for OP2 assignments query
CREATE INDEX idx_review_reviewer_code
    ON Review(reviewer_code);

-- article(conference_acronym, status): for OP4 accepted articles
CREATE INDEX idx_article_conf_status
    ON Article(conference_acronym, status);

-- membership(conference_acronym): for BR9 compound trigger
CREATE INDEX idx_membership_conf
    ON Membership(conference_acronym);


-- after indexes

DELETE FROM PLAN_TABLE;

EXPLAIN PLAN SET STATEMENT_ID = 'Q1_AFTER' FOR
    SELECT COUNT(*) FROM Review WHERE article_id = 1;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1_AFTER', 'BASIC'));
-- should use INDEX RANGE SCAN on idx_review_article_id

EXPLAIN PLAN SET STATEMENT_ID = 'Q2_AFTER' FOR
    SELECT rev.article_id
    FROM Review rev
    WHERE rev.reviewer_code = 'ORG_1_1';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q2_AFTER', 'BASIC'));
-- should use idx_review_reviewer_code

EXPLAIN PLAN SET STATEMENT_ID = 'Q3_AFTER' FOR
    SELECT art.category, art.title, art.avg_global_score
    FROM Article art
    WHERE art.conference_acronym = 'CONF_1'
      AND art.status = 'accepted'
    ORDER BY art.category, art.title;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q3_AFTER', 'BASIC'));
-- should use idx_article_conf_status

EXPLAIN PLAN SET STATEMENT_ID = 'Q4_AFTER' FOR
    SELECT COUNT(*) FROM Membership
    WHERE conference_acronym = 'CONF_1';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q4_AFTER', 'BASIC'));
-- should use idx_membership_conf


-- summary: all indexes on our tables
SELECT index_name, table_name, column_name, column_position
FROM user_ind_columns
WHERE table_name IN (
    'REVIEW', 'ARTICLE', 'MEMBERSHIP', 'AUTHORSHIP',
    'CONFERENCE', 'ORGANIZER', 'AUTHOR', 'SPONSOR'
)
ORDER BY table_name, index_name, column_position;
