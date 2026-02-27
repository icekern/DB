-- stored procedures and utility constructors

-- OP1: submit a new article
CREATE OR REPLACE PROCEDURE prc_submit_article (
    p_conf_acronym IN VARCHAR2,
    p_title IN VARCHAR2,
    p_category IN VARCHAR2,
    p_contact_code IN VARCHAR2,
    p_out_article_id OUT NUMBER
)
AS
    v_seq NUMBER;
BEGIN
    SELECT NVL(MAX(seq_number), 0) + 1 INTO v_seq
    FROM Article
    WHERE conference_acronym = p_conf_acronym;

    INSERT INTO Article (
        conference_acronym, seq_number, title, category, status, contact_author_code
    ) VALUES (
        p_conf_acronym, v_seq, p_title, p_category, 'pending', p_contact_code
    ) RETURNING article_id INTO p_out_article_id;

    INSERT INTO Authorship (article_id, author_code)
    VALUES (p_out_article_id, p_contact_code); -- contact is also an author

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- assign reviewer to article (creates a stub review)
CREATE OR REPLACE PROCEDURE prc_assign_reviewer (
    p_article_id IN NUMBER,
    p_reviewer_code IN VARCHAR2
)
AS
    v_code VARCHAR2(20);
BEGIN
    v_code := 'REV-' || p_article_id || '-' || SUBSTR(p_reviewer_code, 1, 4);

    INSERT INTO Review (
        code, review_date, article_id, reviewer_code
    ) VALUES (
        v_code, SYSDATE, p_article_id, p_reviewer_code
    );
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- OP3: fill in a review with scores
CREATE OR REPLACE PROCEDURE prc_add_review (
    p_code IN VARCHAR2,
    p_originality IN INT,
    p_significance IN INT,
    p_quality IN INT,
    p_comments IN CLOB,
    p_content IN CLOB
)
AS
    v_global_score INT;
BEGIN
    v_global_score := ROUND((p_originality + p_significance + p_quality) / 3);

    UPDATE Review
    SET review_date = SYSDATE,
        content = p_content,
        originality = p_originality,
        significance = p_significance,
        quality = p_quality,
        global_score = v_global_score,
        comments = p_comments
    WHERE code = p_code;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- OP2: get articles assigned to a reviewer
CREATE OR REPLACE PROCEDURE prc_get_reviewer_assignments (
    p_reviewer_code IN VARCHAR2,
    p_cursor OUT SYS_REFCURSOR
)
AS
BEGIN
    OPEN p_cursor FOR
        SELECT
            art.title,
            art.category,
            (
                SELECT LISTAGG(a.name, ', ') WITHIN GROUP (ORDER BY a.name)
                FROM Authorship auth
                JOIN Author a ON auth.author_code = a.code
                WHERE auth.article_id = art.article_id
            ) AS authors_list
        FROM Review rev
        JOIN Article art ON rev.article_id = art.article_id
        WHERE rev.reviewer_code = p_reviewer_code;
END;
/

-- OP4: accepted articles for a conference
CREATE OR REPLACE PROCEDURE prc_get_accepted_articles (
    p_acronym IN VARCHAR2,
    p_cursor OUT SYS_REFCURSOR
)
AS
BEGIN
    OPEN p_cursor FOR
        SELECT
            art.category,
            art.title,
            a.name AS contact_author_name,
            a.email AS contact_author_email,
            art.avg_global_score
        FROM Article art
        JOIN Author a ON art.contact_author_code = a.code
        WHERE art.conference_acronym = p_acronym
          AND art.status = 'accepted'
        ORDER BY art.category, art.title;
END;
/

-- utility: create conference + committee + area indications in one call
CREATE OR REPLACE PROCEDURE util_init_conference (
    p_acronym    IN VARCHAR2,
    p_name       IN VARCHAR2,
    p_location   IN VARCHAR2,
    p_url        IN VARCHAR2,
    p_org_codes  IN VARCHAR2,
    p_area_acr   IN VARCHAR2
)
AS
    v_org   VARCHAR2(20);
    v_area  VARCHAR2(20);
    v_pos   INT;
    v_str   VARCHAR2(4000);
BEGIN
    INSERT INTO Conference (acronym, name, location, homepage_url)
    VALUES (p_acronym, p_name, p_location, p_url);

    v_str := p_org_codes || ',';
    WHILE INSTR(v_str, ',') > 0 LOOP
        v_pos := INSTR(v_str, ',');
        v_org := TRIM(SUBSTR(v_str, 1, v_pos - 1));
        v_str := SUBSTR(v_str, v_pos + 1);

        INSERT INTO Membership (organizer_code, conference_acronym)
        VALUES (v_org, p_acronym);

        DECLARE
            v_astr VARCHAR2(4000) := p_area_acr || ',';
            v_apos INT;
        BEGIN
            WHILE INSTR(v_astr, ',') > 0 LOOP
                v_apos := INSTR(v_astr, ',');
                v_area := TRIM(SUBSTR(v_astr, 1, v_apos - 1));
                v_astr := SUBSTR(v_astr, v_apos + 1);
                BEGIN
                    INSERT INTO AreaIndication
                        (organizer_code, conference_acronym, area_acronym)
                    VALUES (v_org, p_acronym, v_area);
                EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;
            END LOOP;
        END;
    END LOOP;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- utility: register article with multiple authors and areas
CREATE OR REPLACE PROCEDURE util_register_article (
    p_conf_acronym   IN  VARCHAR2,
    p_title          IN  VARCHAR2,
    p_category       IN  VARCHAR2,
    p_contact_code   IN  VARCHAR2,
    p_author_codes   IN  VARCHAR2,
    p_area_acronyms  IN  VARCHAR2,
    p_out_article_id OUT NUMBER
)
AS
    v_seq  NUMBER;
    v_code VARCHAR2(20);
    v_area VARCHAR2(20);
    v_pos  INT;
    v_str  VARCHAR2(4000);
BEGIN
    SELECT NVL(MAX(seq_number), 0) + 1 INTO v_seq
    FROM Article WHERE conference_acronym = p_conf_acronym;

    INSERT INTO Article (
        conference_acronym, seq_number, title, category,
        status, contact_author_code
    ) VALUES (
        p_conf_acronym, v_seq, p_title, p_category,
        'pending', p_contact_code
    ) RETURNING article_id INTO p_out_article_id;

    v_str := p_author_codes || ',';
    WHILE INSTR(v_str, ',') > 0 LOOP
        v_pos := INSTR(v_str, ',');
        v_code := TRIM(SUBSTR(v_str, 1, v_pos - 1));
        v_str := SUBSTR(v_str, v_pos + 1);
        BEGIN
            INSERT INTO Authorship (article_id, author_code)
            VALUES (p_out_article_id, v_code);
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
    END LOOP;

    v_str := p_area_acronyms || ',';
    WHILE INSTR(v_str, ',') > 0 LOOP
        v_pos := INSTR(v_str, ',');
        v_area := TRIM(SUBSTR(v_str, 1, v_pos - 1));
        v_str := SUBSTR(v_str, v_pos + 1);
        BEGIN
            INSERT INTO ArticleAreaIndication (article_id, area_acronym)
            VALUES (p_out_article_id, v_area);
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;
    END LOOP;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
