-- BR2: reviewer must belong to the conference committee
-- fires: BEFORE INSERT OR UPDATE ON Review

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
