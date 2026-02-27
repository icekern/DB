-- BR5: all assigned reviews must be completed before status can change
-- BR6: at least 2 reviews must exist before status can change
-- fires: BEFORE UPDATE OF status ON Article

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
