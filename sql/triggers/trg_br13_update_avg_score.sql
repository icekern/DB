-- BR13: keep avg_global_score in sync (compound trigger)
-- fires: FOR INSERT OR UPDATE OF global_score OR DELETE ON Review

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
