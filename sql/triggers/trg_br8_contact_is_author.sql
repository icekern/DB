-- BR8: contact author must be in the article's authorship
-- fires: AFTER INSERT OR UPDATE ON Article
-- skips INSERT (authorship added after the article row)

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

    IF v_is_author = 0 AND NOT INSERTING THEN
        RAISE_APPLICATION_ERROR(-20008, 'BR8: Contact author must be one of the authors of the article.');
    END IF;
END;
/
