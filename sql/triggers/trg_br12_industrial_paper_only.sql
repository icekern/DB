-- BR12: partners only for industrial papers
-- fires: BEFORE INSERT OR UPDATE ON Contribution

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
