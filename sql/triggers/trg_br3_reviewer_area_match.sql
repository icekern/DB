-- BR3: reviewer areas must overlap with article areas
-- fires: BEFORE INSERT OR UPDATE ON Review

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
