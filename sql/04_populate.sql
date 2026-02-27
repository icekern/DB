-- population script (matches volume table from ch.3)
-- 100 conferences, 400 organizers, 3600 authors, 1200 articles, 3600 reviews

SET SERVEROUTPUT ON;

-- disable all triggers during population
ALTER TABLE Review       DISABLE ALL TRIGGERS;
ALTER TABLE Contribution DISABLE ALL TRIGGERS;
ALTER TABLE Article      DISABLE ALL TRIGGERS;
ALTER TABLE Membership   DISABLE ALL TRIGGERS;

DECLARE
   v_conf_acronym VARCHAR2(50);
   v_org_code     VARCHAR2(20);
   v_author_code  VARCHAR2(20);
   v_article_id   NUMBER;
   v_review_code  VARCHAR2(20);
   v_category     VARCHAR2(50);
   v_area_acronym VARCHAR2(20);
BEGIN
   -- clean up previous data (reverse FK order)
   DELETE FROM Review;
   DELETE FROM Contribution;
   DELETE FROM ArticleAreaIndication;
   DELETE FROM Authorship;
   DELETE FROM Article;
   DELETE FROM AreaIndication;
   DELETE FROM Membership;
   DELETE FROM Sponsorship;
   DELETE FROM Partner;
   DELETE FROM Author;
   DELETE FROM Organizer;
   DELETE FROM ResearchArea;
   DELETE FROM Conference;
   DELETE FROM Sponsor;

   -- research areas
   INSERT INTO ResearchArea (area_acronym, area_name, description)
   VALUES ('DB_SYS', 'Database Systems', 'Storage, querying, and transaction management.');
   INSERT INTO ResearchArea (area_acronym, area_name, description)
   VALUES ('SW_ENG', 'Software Engineering', 'Software processes, testing, and architecture.');
   INSERT INTO ResearchArea (area_acronym, area_name, description)
   VALUES ('AI', 'Artificial Intelligence', 'Machine learning, reasoning, and agents.');

   FOR i IN 1..20 LOOP
      INSERT INTO Sponsor (name) VALUES ('Sponsor_' || i);
   END LOOP;

   FOR i IN 1..480 LOOP
      INSERT INTO Partner (code, name, address)
      VALUES ('P_' || i, 'Partner Corp ' || i, 'City ' || i);
   END LOOP;

   FOR i IN 1..3600 LOOP
      INSERT INTO Author (code, name, affiliation, address, phone, email)
      VALUES ('A_' || i, 'Author ' || i, 'Uni_' || MOD(i, 50),
              'Addr ' || i, '555-' || i, 'auth' || i || '@test.com');
   END LOOP;

   FOR c IN 1..100 LOOP
      v_conf_acronym := 'CONF_' || c;

      INSERT INTO Conference (acronym, name, location, homepage_url)
      VALUES (v_conf_acronym, 'Conference ' || c,
              'City_' || c, 'http://conf' || c || '.org');

      FOR s IN 1..5 LOOP
         INSERT INTO Sponsorship (sponsor_name, conference_acronym, funding_date, funded_amount)
         VALUES ('Sponsor_' || (MOD((c - 1) * 5 + s - 1, 20) + 1), v_conf_acronym, SYSDATE, 10000 + s * 1000);
      END LOOP;

      FOR o IN 1..4 LOOP
         v_org_code := 'ORG_' || c || '_' || o;

         INSERT INTO Organizer (code, name, affiliation, address, phone, email)
         VALUES (v_org_code, 'Org ' || v_org_code, 'Affil_' || MOD(o, 10),
                 'Addr_' || o, '123-' || o, 'org' || v_org_code || '@test.com');

         INSERT INTO Membership (organizer_code, conference_acronym)
         VALUES (v_org_code, v_conf_acronym);

         v_area_acronym := CASE MOD(o, 3)
             WHEN 0 THEN 'DB_SYS'
             WHEN 1 THEN 'SW_ENG'
             ELSE        'AI'
         END;

         INSERT INTO AreaIndication (organizer_code, conference_acronym, area_acronym)
         VALUES (v_org_code, v_conf_acronym, v_area_acronym);
      END LOOP;

      FOR a IN 1..12 LOOP
         IF a <= 2 THEN v_category := 'Industrial Paper';
         ELSIF a <= 4 THEN v_category := 'Tutorial';
         ELSIF a <= 5 THEN v_category := 'Short Paper';
         ELSIF a <= 6 THEN v_category := 'Poster';
         ELSE v_category := 'Research Paper'; END IF;

         v_author_code := 'A_' || ((c - 1) * 12 + a);

         v_area_acronym := CASE MOD(a, 3)
             WHEN 0 THEN 'DB_SYS'
             WHEN 1 THEN 'SW_ENG'
             ELSE        'AI'
         END;

         INSERT INTO Article (conference_acronym, seq_number, title,
                              category, status, contact_author_code)
         VALUES (v_conf_acronym, a, 'Article ' || c || '_' || a,
                 v_category, 'pending', v_author_code)
         RETURNING article_id INTO v_article_id;

         INSERT INTO Authorship (article_id, author_code)
         VALUES (v_article_id, v_author_code);
         INSERT INTO Authorship (article_id, author_code)
         VALUES (v_article_id, 'A_' || (MOD((c - 1) * 12 + a, 3600) + 1));
         INSERT INTO Authorship (article_id, author_code)
         VALUES (v_article_id, 'A_' || (MOD((c - 1) * 12 + a + 1, 3600) + 1));

         INSERT INTO ArticleAreaIndication (article_id, area_acronym)
         VALUES (v_article_id, v_area_acronym);
         BEGIN
             INSERT INTO ArticleAreaIndication (article_id, area_acronym)
             VALUES (v_article_id, CASE v_area_acronym
                 WHEN 'DB_SYS' THEN 'SW_ENG'
                 WHEN 'SW_ENG' THEN 'AI'
                 ELSE 'DB_SYS'
             END);
         EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
         END;

         IF v_category = 'Industrial Paper' THEN
             INSERT INTO Contribution (article_id, partner_code)
             VALUES (v_article_id, 'P_' || (MOD(a, 480) + 1));
             INSERT INTO Contribution (article_id, partner_code)
             VALUES (v_article_id, 'P_' || (MOD(a + 1, 480) + 1));
         END IF;

         FOR r IN 1..3 LOOP
             v_review_code := 'REV_' || v_article_id || '_' || r;
             v_org_code := 'ORG_' || c || '_' || r;

             BEGIN
                 INSERT INTO AreaIndication (organizer_code, conference_acronym, area_acronym)
                 VALUES (v_org_code, v_conf_acronym, v_area_acronym);
             EXCEPTION
                 WHEN DUP_VAL_ON_INDEX THEN NULL;
             END;

             INSERT INTO Review (code, review_date, content, originality,
                                 significance, quality, global_score,
                                 article_id, reviewer_code)
             VALUES (v_review_code, SYSDATE, 'Review content for article ' || v_article_id,
                     5 + MOD(r, 5), 5 + MOD(r + 1, 5), 5 + MOD(r + 2, 5),
                     ROUND((5 + MOD(r, 5) + 5 + MOD(r + 1, 5) + 5 + MOD(r + 2, 5)) / 3),
                     v_article_id, v_org_code);
         END LOOP;

      END LOOP;
   END LOOP;

   COMMIT;
   DBMS_OUTPUT.PUT_LINE('Population complete.');
END;
/

-- re-enable all triggers
ALTER TABLE Membership   ENABLE ALL TRIGGERS;
ALTER TABLE Article      ENABLE ALL TRIGGERS;
ALTER TABLE Contribution ENABLE ALL TRIGGERS;
ALTER TABLE Review       ENABLE ALL TRIGGERS;
