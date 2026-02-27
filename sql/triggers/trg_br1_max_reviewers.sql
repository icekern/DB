-- BR1: max 4 reviewers per article
-- fires: BEFORE INSERT ON Review

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
