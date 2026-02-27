-- triggers for business rules
-- BR4/BR7/BR10 are just CHECK constraints, no trigger needed

-- BR1: max 4 reviewers per article
CREATE OR REPLACE TRIGGER trg_br1_max_reviewers
BEFORE INSERT ON Review
FOR EACH ROW
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM Review
    WHERE article_id = :NEW.article_id;

    IF v_count >= 4 THEN
        RAISE_APPLICATION_ERROR(-20001, 'BR1: An article cannot have more than 4 reviewers.');
    END IF;
END;
/

-- BR2: reviewer must be in the conference committee
CREATE OR REPLACE TRIGGER trg_br2_reviewer_conf_match
BEFORE INSERT OR UPDATE ON Review
FOR EACH ROW
DECLARE
    v_article_conf        VARCHAR2(50);
    v_reviewer_conf_count INT;
BEGIN
    SELECT conference_acronym INTO v_article_conf
    FROM Article WHERE article_id = :NEW.article_id;

    SELECT COUNT(*) INTO v_reviewer_conf_count
    FROM Membership
    WHERE organizer_code     = :NEW.reviewer_code
      AND conference_acronym = v_article_conf;

    IF v_reviewer_conf_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'BR2: Reviewer must be in the program committee of the conference.');
    END IF;
END;
/

-- BR3: reviewer areas must overlap with article areas
CREATE OR REPLACE TRIGGER trg_br3_reviewer_area_match
BEFORE INSERT OR UPDATE ON Review
FOR EACH ROW
DECLARE
    v_overlap INT;
BEGIN
    SELECT COUNT(*) INTO v_overlap
    FROM AreaIndication ai
    JOIN ArticleAreaIndication aai ON aai.area_acronym = ai.area_acronym
    JOIN Article art ON aai.article_id = art.article_id
    WHERE ai.organizer_code     = :NEW.reviewer_code
      AND aai.article_id        = :NEW.article_id
      AND ai.conference_acronym = art.conference_acronym;

    IF v_overlap = 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'BR3: Reviewer research areas must overlap with the article areas.');
    END IF;
END;
/

-- BR5/BR6: status can change only when all reviews done (BR5) and at least 2 exist (BR6)
CREATE OR REPLACE TRIGGER trg_br5_br6_article_status
BEFORE UPDATE OF status ON Article
FOR EACH ROW
DECLARE
    v_total_reviews     INT;
    v_completed_reviews INT;
BEGIN
    IF :OLD.status = 'pending' AND :NEW.status != 'pending' THEN

        SELECT COUNT(*)
        INTO v_total_reviews
        FROM Review
        WHERE article_id = :NEW.article_id;

        SELECT COUNT(*)
        INTO v_completed_reviews
        FROM Review
        WHERE article_id = :NEW.article_id
          AND global_score IS NOT NULL;

        IF v_total_reviews < 2 THEN
            RAISE_APPLICATION_ERROR(-20006, 'BR6: Status cannot be updated without at least 2 reviews.');
        END IF;

        IF v_total_reviews != v_completed_reviews THEN
            RAISE_APPLICATION_ERROR(-20005, 'BR5: Status cannot be updated until all assigned reviews are completed.');
        END IF;
    END IF;
END;
/

-- BR8: contact author must be one of the article authors
CREATE OR REPLACE TRIGGER trg_br8_contact_is_author
AFTER INSERT OR UPDATE ON Article
FOR EACH ROW
DECLARE
    v_is_author INT;
BEGIN
    SELECT COUNT(*) INTO v_is_author
    FROM Authorship
    WHERE article_id  = :NEW.article_id
      AND author_code = :NEW.contact_author_code;

    IF v_is_author = 0 AND NOT INSERTING THEN -- skip on insert, authorship added after
        RAISE_APPLICATION_ERROR(-20008, 'BR8: Contact author must be one of the authors of the article.');
    END IF;
END;
/

-- BR9: min 2 committee members per conference (compound trigger)
CREATE OR REPLACE TRIGGER trg_br9_min_committee
FOR DELETE ON Membership
COMPOUND TRIGGER

    TYPE t_confs IS TABLE OF VARCHAR2(50) INDEX BY PLS_INTEGER;
    g_confs t_confs;
    g_idx   PLS_INTEGER := 0;

    AFTER EACH ROW IS
    BEGIN
        g_idx := g_idx + 1;
        g_confs(g_idx) := :OLD.conference_acronym;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_count INT;
    BEGIN
        FOR i IN 1..g_idx LOOP
            SELECT COUNT(*) INTO v_count
            FROM Membership
            WHERE conference_acronym = g_confs(i);

            IF v_count < 2 THEN
                RAISE_APPLICATION_ERROR(-20009,
                    'BR9: A conference must have at least 2 program committee members.');
            END IF;
        END LOOP;
    END AFTER STATEMENT;

END trg_br9_min_committee;
/

-- BR11: article accepted only if avg score >= 5
CREATE OR REPLACE TRIGGER trg_br11_acceptance_threshold
BEFORE UPDATE OF status ON Article
FOR EACH ROW
BEGIN
    IF :NEW.status = 'accepted' AND :NEW.avg_global_score < 5 THEN
        RAISE_APPLICATION_ERROR(-20011, 'BR11: An article can only be accepted if avg_global_score >= 5.');
    END IF;
END;
/

-- BR12: partners only for industrial papers
CREATE OR REPLACE TRIGGER trg_br12_industrial_paper_only
BEFORE INSERT OR UPDATE ON Contribution
FOR EACH ROW
DECLARE
    v_category VARCHAR2(50);
BEGIN
    SELECT category INTO v_category
    FROM Article
    WHERE article_id = :NEW.article_id;

    IF v_category != 'Industrial Paper' THEN
        RAISE_APPLICATION_ERROR(-20012, 'BR12: Partners can only contribute to Industrial Papers.');
    END IF;
END;
/

-- BR13: keep avg_global_score in sync (compound trigger to avoid mutating table)
CREATE OR REPLACE TRIGGER trg_br13_update_avg_score
FOR INSERT OR UPDATE OF global_score OR DELETE ON Review
COMPOUND TRIGGER

    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    g_ids t_ids;
    g_idx PLS_INTEGER := 0;

    AFTER EACH ROW IS
    BEGIN
        g_idx := g_idx + 1;
        IF DELETING THEN
            g_ids(g_idx) := :OLD.article_id;
        ELSE
            g_ids(g_idx) := :NEW.article_id;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_avg FLOAT;
    BEGIN
        FOR i IN 1..g_idx LOOP
            SELECT NVL(AVG(global_score), 0)
            INTO v_avg
            FROM Review
            WHERE article_id = g_ids(i);

            UPDATE Article
            SET avg_global_score = v_avg
            WHERE article_id = g_ids(i);
        END LOOP;
    END AFTER STATEMENT;

END trg_br13_update_avg_score;
/
