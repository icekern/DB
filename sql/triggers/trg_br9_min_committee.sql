-- BR9: min 2 committee members per conference (compound trigger)
-- fires: FOR DELETE ON Membership

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
