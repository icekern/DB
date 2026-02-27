-- test script for all triggers (BR1-BR13)
-- run after tables + triggers + population

SET SERVEROUTPUT ON;

PROMPT ========================================
PROMPT TRIGGER TESTING
PROMPT ========================================

-- BR1: max 4 reviewers
PROMPT
PROMPT --- BR1: Max 4 reviewers per article ---

BEGIN
    INSERT INTO AreaIndication (organizer_code, conference_acronym, area_acronym)
    VALUES ('ORG_1_4', 'CONF_1', 'SW_ENG');
EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
END;
/

-- 4th review should work
DECLARE
    v_aid NUMBER;
BEGIN
    SELECT article_id INTO v_aid FROM Article
    WHERE conference_acronym = 'CONF_1' AND seq_number = 1;

    INSERT INTO Review (code, review_date, article_id, reviewer_code)
    VALUES ('TEST_BR1_OK', SYSDATE, v_aid, 'ORG_1_4');
    DBMS_OUTPUT.PUT_LINE('BR1 OK: 4th reviewer accepted.');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('BR1 UNEXPECTED: ' || SQLERRM);
        ROLLBACK;
END;
/

-- 5th should fail
DECLARE
    v_aid NUMBER;
BEGIN
    SELECT article_id INTO v_aid FROM Article
    WHERE conference_acronym = 'CONF_1' AND seq_number = 1;

    INSERT INTO Review (code, review_date, article_id, reviewer_code)
    VALUES ('TEST_BR1_4', SYSDATE, v_aid, 'ORG_1_4');

    INSERT INTO Organizer (code, name) VALUES ('ORG_TEST', 'Test Org');
    INSERT INTO Membership (organizer_code, conference_acronym)
    VALUES ('ORG_TEST', 'CONF_1');
    INSERT INTO AreaIndication (organizer_code, conference_acronym, area_acronym)
    VALUES ('ORG_TEST', 'CONF_1', 'SW_ENG');

    INSERT INTO Review (code, review_date, article_id, reviewer_code)
    VALUES ('TEST_BR1_FAIL', SYSDATE, v_aid, 'ORG_TEST');

    DBMS_OUTPUT.PUT_LINE('BR1 FAIL: Should have raised error!');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20001 THEN
            DBMS_OUTPUT.PUT_LINE('BR1 PASS: 5th reviewer blocked.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR1 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR2: reviewer must be in committee
PROMPT
PROMPT --- BR2: Reviewer must be in committee ---

DECLARE
    v_aid NUMBER;
BEGIN
    SELECT article_id INTO v_aid FROM Article
    WHERE conference_acronym = 'CONF_1' AND seq_number = 1;

    INSERT INTO Organizer (code, name) VALUES ('ORG_OUTSIDE', 'Outside Org');
    -- area in CONF_1 lets BR3 pass so only BR2 (membership) is tested
    INSERT INTO AreaIndication (organizer_code, conference_acronym, area_acronym)
    VALUES ('ORG_OUTSIDE', 'CONF_1', 'SW_ENG');

    INSERT INTO Review (code, review_date, article_id, reviewer_code)
    VALUES ('TEST_BR2_FAIL', SYSDATE, v_aid, 'ORG_OUTSIDE');

    DBMS_OUTPUT.PUT_LINE('BR2 FAIL: Should have raised error!');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20002 THEN
            DBMS_OUTPUT.PUT_LINE('BR2 PASS: Non-member reviewer blocked.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR2 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR3: area overlap
PROMPT
PROMPT --- BR3: Research area overlap ---

BEGIN
    INSERT INTO Organizer (code, name) VALUES ('ORG_NOAREA', 'No Area Match');
    INSERT INTO Membership (organizer_code, conference_acronym)
    VALUES ('ORG_NOAREA', 'CONF_1');
    INSERT INTO AreaIndication (organizer_code, conference_acronym, area_acronym)
    VALUES ('ORG_NOAREA', 'CONF_1', 'DB_SYS');

    INSERT INTO Article (conference_acronym, seq_number, title, category,
                         status, contact_author_code)
    VALUES ('CONF_1', 99, 'Test BR3 Article', 'Research Paper', 'pending', 'A_1');

    DECLARE
        v_aid NUMBER;
    BEGIN
        SELECT article_id INTO v_aid FROM Article
        WHERE conference_acronym = 'CONF_1' AND seq_number = 99;

        INSERT INTO Authorship (article_id, author_code) VALUES (v_aid, 'A_1');
        INSERT INTO ArticleAreaIndication (article_id, area_acronym)
        VALUES (v_aid, 'AI');

        -- ORG_NOAREA has DB_SYS, article has AI -> no overlap
        INSERT INTO Review (code, review_date, article_id, reviewer_code)
        VALUES ('TEST_BR3_FAIL', SYSDATE, v_aid, 'ORG_NOAREA');

        DBMS_OUTPUT.PUT_LINE('BR3 FAIL: Should have raised error!');
    END;
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20003 THEN
            DBMS_OUTPUT.PUT_LINE('BR3 PASS: No area overlap blocked.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR3 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR4: score range (CHECK constraint)
PROMPT
PROMPT --- BR4: Score range CHECK ---

DECLARE
    v_aid NUMBER;
BEGIN
    SELECT article_id INTO v_aid FROM Article
    WHERE conference_acronym = 'CONF_1' AND seq_number = 1;
    UPDATE Review SET originality = 11 WHERE code = 'REV_' || v_aid || '_1';
    DBMS_OUTPUT.PUT_LINE('BR4 FAIL: Should have raised error!');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('BR4 PASS: Score > 10 blocked by CHECK.');
        ROLLBACK;
END;
/

DECLARE
    v_aid NUMBER;
BEGIN
    SELECT article_id INTO v_aid FROM Article
    WHERE conference_acronym = 'CONF_1' AND seq_number = 1;
    UPDATE Review SET quality = -1 WHERE code = 'REV_' || v_aid || '_1';
    DBMS_OUTPUT.PUT_LINE('BR4 FAIL: Should have raised error!');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('BR4 PASS: Score < 0 blocked by CHECK.');
        ROLLBACK;
END;
/

-- BR5/BR6: status change conditions
PROMPT
PROMPT --- BR5/BR6: Status change conditions ---

-- BR6: < 2 reviews
BEGIN
    INSERT INTO Article (conference_acronym, seq_number, title, category,
                         status, contact_author_code)
    VALUES ('CONF_1', 98, 'Test BR6 Article', 'Research Paper', 'pending', 'A_1');

    DECLARE
        v_aid NUMBER;
    BEGIN
        SELECT article_id INTO v_aid FROM Article
        WHERE conference_acronym = 'CONF_1' AND seq_number = 98;

        INSERT INTO Authorship (article_id, author_code) VALUES (v_aid, 'A_1');
        INSERT INTO ArticleAreaIndication (article_id, area_acronym)
        VALUES (v_aid, 'SW_ENG');

        INSERT INTO Review (code, review_date, content, originality,
                           significance, quality, global_score,
                           article_id, reviewer_code)
        VALUES ('TEST_BR6_R1', SYSDATE, 'Test', 7, 7, 7, 7, v_aid, 'ORG_1_1');

        UPDATE Article SET status = 'accepted' WHERE article_id = v_aid;
        DBMS_OUTPUT.PUT_LINE('BR6 FAIL: Should have raised error!');
    END;
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20006 THEN
            DBMS_OUTPUT.PUT_LINE('BR6 PASS: < 2 reviews blocked.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR6 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR5: incomplete reviews
BEGIN
    INSERT INTO Article (conference_acronym, seq_number, title, category,
                         status, contact_author_code)
    VALUES ('CONF_1', 97, 'Test BR5 Article', 'Research Paper', 'pending', 'A_1');

    DECLARE
        v_aid NUMBER;
    BEGIN
        SELECT article_id INTO v_aid FROM Article
        WHERE conference_acronym = 'CONF_1' AND seq_number = 97;

        INSERT INTO Authorship (article_id, author_code) VALUES (v_aid, 'A_1');
        INSERT INTO ArticleAreaIndication (article_id, area_acronym)
        VALUES (v_aid, 'SW_ENG');

        INSERT INTO Review (code, review_date, content, originality,
                           significance, quality, global_score,
                           article_id, reviewer_code)
        VALUES ('TEST_BR5_R1', SYSDATE, 'Done', 7, 7, 7, 7, v_aid, 'ORG_1_1');

        INSERT INTO Review (code, review_date, article_id, reviewer_code)
        VALUES ('TEST_BR5_R2', SYSDATE, v_aid, 'ORG_1_2');

        UPDATE Article SET status = 'accepted' WHERE article_id = v_aid;
        DBMS_OUTPUT.PUT_LINE('BR5 FAIL: Should have raised error!');
    END;
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20005 THEN
            DBMS_OUTPUT.PUT_LINE('BR5 PASS: Incomplete reviews blocked.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR5 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR7: single conference (FK design)
PROMPT
PROMPT --- BR7: Single conference (FK constraint) ---
PROMPT BR7: Enforced by FK design. No trigger needed.

-- BR8: contact author must be an author
PROMPT
PROMPT --- BR8: Contact author subset ---

DECLARE
    v_aid NUMBER;
BEGIN
    -- article CONF_1 seq=1 has authors A_1,A_2,A_3; A_3600 is not one of them
    SELECT article_id INTO v_aid FROM Article
    WHERE conference_acronym = 'CONF_1' AND seq_number = 1;

    UPDATE Article
    SET contact_author_code = 'A_3600'
    WHERE article_id = v_aid;

    DBMS_OUTPUT.PUT_LINE('BR8 FAIL: Should have raised error!');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20008 THEN
            DBMS_OUTPUT.PUT_LINE('BR8 PASS: Non-author contact blocked.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR8 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR9: min 2 committee members
PROMPT
PROMPT --- BR9: Min committee size ---

BEGIN
    DELETE FROM Membership
    WHERE organizer_code = 'ORG_1_3' AND conference_acronym = 'CONF_1';
    DELETE FROM Membership
    WHERE organizer_code = 'ORG_1_4' AND conference_acronym = 'CONF_1';
    DELETE FROM Membership
    WHERE organizer_code = 'ORG_1_2' AND conference_acronym = 'CONF_1';

    DBMS_OUTPUT.PUT_LINE('BR9 FAIL: Should have raised error!');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20009 THEN
            DBMS_OUTPUT.PUT_LINE('BR9 PASS: < 2 members blocked.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR9 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR10: positive sponsorship amount (CHECK)
PROMPT
PROMPT --- BR10: Positive sponsorship amount ---

BEGIN
    INSERT INTO Sponsorship (sponsor_name, conference_acronym,
                             funding_date, funded_amount)
    VALUES ('Sponsor_1', 'CONF_2', SYSDATE, -500);
    DBMS_OUTPUT.PUT_LINE('BR10 FAIL: Should have raised error!');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('BR10 PASS: Negative amount blocked.');
        ROLLBACK;
END;
/

-- BR11: acceptance threshold (avg >= 5)
PROMPT
PROMPT --- BR11: Acceptance score threshold ---

BEGIN
    INSERT INTO Article (conference_acronym, seq_number, title, category,
                         status, contact_author_code)
    VALUES ('CONF_1', 96, 'Low Score Article', 'Research Paper', 'pending', 'A_1');

    DECLARE
        v_aid NUMBER;
    BEGIN
        SELECT article_id INTO v_aid FROM Article
        WHERE conference_acronym = 'CONF_1' AND seq_number = 96;

        INSERT INTO Authorship (article_id, author_code) VALUES (v_aid, 'A_1');
        INSERT INTO ArticleAreaIndication (article_id, area_acronym)
        VALUES (v_aid, 'SW_ENG');

        INSERT INTO Review (code, review_date, content, originality,
                           significance, quality, global_score,
                           article_id, reviewer_code)
        VALUES ('TEST_BR11_R1', SYSDATE, 'Bad', 2, 2, 2, 2, v_aid, 'ORG_1_1');

        INSERT INTO Review (code, review_date, content, originality,
                           significance, quality, global_score,
                           article_id, reviewer_code)
        VALUES ('TEST_BR11_R2', SYSDATE, 'Bad', 2, 2, 2, 2, v_aid, 'ORG_1_2');

        UPDATE Article SET status = 'accepted' WHERE article_id = v_aid;
        DBMS_OUTPUT.PUT_LINE('BR11 FAIL: Should have raised error!');
    END;
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20011 THEN
            DBMS_OUTPUT.PUT_LINE('BR11 PASS: Low avg score blocked acceptance.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR11 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR12: partners only for industrial papers
PROMPT
PROMPT --- BR12: Industrial paper only ---

BEGIN
    DECLARE
        v_aid NUMBER;
    BEGIN
        SELECT article_id INTO v_aid FROM Article
        WHERE conference_acronym = 'CONF_1' AND seq_number = 7;

        INSERT INTO Contribution (article_id, partner_code)
        VALUES (v_aid, 'P_1');

        DBMS_OUTPUT.PUT_LINE('BR12 FAIL: Should have raised error!');
    END;
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20012 THEN
            DBMS_OUTPUT.PUT_LINE('BR12 PASS: Non-industrial contribution blocked.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('BR12 UNEXPECTED: ' || SQLERRM);
        END IF;
        ROLLBACK;
END;
/

-- BR13: avg score auto-update
PROMPT
PROMPT --- BR13: Avg score auto-update ---

DECLARE
    v_aid NUMBER;
    v_avg FLOAT;
BEGIN
    SELECT article_id INTO v_aid FROM Article
    WHERE conference_acronym = 'CONF_1' AND seq_number = 1;

    SELECT avg_global_score INTO v_avg FROM Article WHERE article_id = v_aid;
    DBMS_OUTPUT.PUT_LINE('BR13: Current avg = ' || v_avg);

    UPDATE Review SET global_score = 10
    WHERE code = 'REV_' || v_aid || '_1';

    SELECT avg_global_score INTO v_avg FROM Article WHERE article_id = v_aid;
    DBMS_OUTPUT.PUT_LINE('BR13: After update avg = ' || v_avg);

    IF v_avg != 0 THEN
        DBMS_OUTPUT.PUT_LINE('BR13 PASS: Avg score updated automatically.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('BR13 FAIL: Avg not updated.');
    END IF;

    ROLLBACK;
END;
/

PROMPT
PROMPT ========================================
PROMPT TRIGGER TESTING - COMPLETE
PROMPT ========================================
