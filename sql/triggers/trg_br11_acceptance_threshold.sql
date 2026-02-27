-- BR11: accepted only if avg score >= 5
-- fires: BEFORE UPDATE OF status ON Article

CREATE OR REPLACE TRIGGER trg_br11_acceptance_threshold
BEFORE UPDATE OF status ON Article
FOR EACH ROW
BEGIN
    IF :NEW.status = 'accepted' AND :NEW.avg_global_score < 5 THEN
        RAISE_APPLICATION_ERROR(-20011, 'BR11: An article can only be accepted if avg_global_score >= 5.');
    END IF;
END;
/
