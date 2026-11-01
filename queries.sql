-- ============================================================
-- EduTrack — Auditoría de datos con tablas relacionadas
-- ============================================================
-- Base de datos : PostgreSQL (Supabase)
-- Tablas        : students, courses, enrollments
--
-- Relaciones:
--   students.id  1 ── N  enrollments.student_id
--   courses.id   1 ── N  enrollments.course_id
--   students N ── M courses (resuelta mediante enrollments)
--
-- Convenciones:
--   - Alias de tabla: s = students, c = courses, e = enrollments.
--   - Todas las consultas usan al menos un JOIN y ninguna subconsulta.
--   - Todas las consultas son de solo lectura (únicamente SELECT).
-- ============================================================


-- ------------------------------------------------------------
-- CONSULTA 1 — Todas las inscripciones
-- ------------------------------------------------------------
-- Objetivo     : Listar todas las inscripciones con el nombre del
--                estudiante, el título del curso y el porcentaje
--                de completado.
-- Tipo de JOIN : INNER JOIN (enrollments → students, enrollments → courses)
-- Explicación  : Solo se devuelven las inscripciones que tienen
--                correspondencia con un estudiante y con un curso.
--                Ordenado por estudiante y, después, por curso.
-- ------------------------------------------------------------
SELECT
    s.name                  AS student_name,
    c.title                 AS course_title,
    e.completion_percentage AS completion_percentage
FROM enrollments AS e
INNER JOIN students AS s
    ON s.id = e.student_id
INNER JOIN courses AS c
    ON c.id = e.course_id
ORDER BY
    student_name,
    course_title;


-- ------------------------------------------------------------
-- CONSULTA 2 — Estudiantes que han aprobado cursos
-- ------------------------------------------------------------
-- Objetivo     : Listar los estudiantes que han aprobado algún curso,
--                con su email y el título del curso aprobado.
-- Tipo de JOIN : INNER JOIN (enrollments → students, enrollments → courses)
-- Explicación  : Filtro passed = TRUE. Un estudiante aparece una vez
--                por cada curso aprobado, así que puede repetirse.
-- ------------------------------------------------------------
SELECT
    s.name  AS student_name,
    s.email AS student_email,
    c.title AS passed_course_title
FROM enrollments AS e
INNER JOIN students AS s
    ON s.id = e.student_id
INNER JOIN courses AS c
    ON c.id = e.course_id
WHERE e.passed = TRUE
ORDER BY
    student_name,
    passed_course_title;


-- ------------------------------------------------------------
-- CONSULTA 3 — Porcentaje medio de completado por instructor
-- ------------------------------------------------------------
-- Objetivo     : Calcular la media de completion_percentage de las
--                inscripciones en los cursos de cada instructor.
-- Tipo de JOIN : INNER JOIN (courses → enrollments) + GROUP BY
-- Explicación  : Los cursos sin inscripciones no intervienen en la
--                media (INNER JOIN). 'Pending assignment' es un texto,
--                no un NULL, así que se mantiene como un grupo propio.
--                Redondeado a dos decimales; de mayor a menor media.
-- ------------------------------------------------------------
SELECT
    c.instructor_name                      AS instructor_name,
    ROUND(AVG(e.completion_percentage), 2) AS avg_completion_percentage
FROM courses AS c
INNER JOIN enrollments AS e
    ON e.course_id = c.id
GROUP BY
    c.instructor_name
ORDER BY
    avg_completion_percentage DESC,
    instructor_name;


-- ------------------------------------------------------------
-- CONSULTA 4 — Estudiantes sin inscripciones
-- ------------------------------------------------------------
-- Objetivo     : Encontrar los estudiantes que no tienen ninguna
--                fila en enrollments.
-- Tipo de JOIN : LEFT JOIN (students → enrollments)
-- Explicación  : El LEFT JOIN conserva a todos los estudiantes; los
--                que no tienen coincidencia reciben NULL en las
--                columnas de enrollments, y el filtro IS NULL los aísla.
-- ------------------------------------------------------------
SELECT
    s.name  AS student_name,
    s.email AS student_email
FROM students AS s
LEFT JOIN enrollments AS e
    ON e.student_id = s.id
WHERE e.id IS NULL
ORDER BY
    student_name;


-- ------------------------------------------------------------
-- CONSULTA 5 — Cursos sin inscripciones
-- ------------------------------------------------------------
-- Objetivo     : Encontrar los cursos que no tienen inscripciones.
-- Tipo de JOIN : LEFT JOIN (courses → enrollments)
-- Explicación  : Mismo patrón que la consulta 4: el LEFT JOIN
--                conserva todos los cursos e IS NULL aísla los que
--                no tienen coincidencia.
-- ------------------------------------------------------------
SELECT
    c.title    AS course_title,
    c.category AS course_category
FROM courses AS c
LEFT JOIN enrollments AS e
    ON e.course_id = c.id
WHERE e.id IS NULL
ORDER BY
    course_title;


-- ------------------------------------------------------------
-- CONSULTA 6 — Estudiantes inscritos en más de un curso
-- ------------------------------------------------------------
-- Objetivo     : Listar los estudiantes inscritos en más de un curso
--                y cuántos cursos distintos sigue cada uno.
-- Tipo de JOIN : INNER JOIN (students → enrollments) + GROUP BY + HAVING
-- Explicación  : COUNT(DISTINCT e.course_id) cuenta cursos diferentes,
--                de modo que una inscripción repetida en el mismo curso
--                no se contaría dos veces. Se agrupa por s.id además de
--                s.name para no mezclar dos estudiantes con el mismo nombre.
-- ------------------------------------------------------------
SELECT
    s.name                      AS student_name,
    COUNT(DISTINCT e.course_id) AS enrolled_courses
FROM students AS s
INNER JOIN enrollments AS e
    ON e.student_id = s.id
GROUP BY
    s.id,
    s.name
HAVING COUNT(DISTINCT e.course_id) > 1
ORDER BY
    enrolled_courses DESC,
    student_name;


-- ------------------------------------------------------------
-- CONSULTA 7 — Ingresos por categoría
-- ------------------------------------------------------------
-- Objetivo     : Estimar los ingresos mensuales de cada categoría.
-- Tipo de JOIN : INNER JOIN (courses → enrollments) + GROUP BY
-- Fórmula      : inscripciones por curso × courses.monthly_fee actual,
--                sumado por categoría. Como el JOIN genera una fila por
--                inscripción, SUM(c.monthly_fee) es exactamente esa suma.
-- Explicación  : Usa el precio ACTUAL del curso (courses.monthly_fee),
--                no enrollments.monthly_fee_paid. El resultado es una
--                cifra mensual teórica basada en los precios actuales y
--                el número de inscripciones; no son ingresos históricos
--                cobrados ni ingresos netos.
-- ------------------------------------------------------------
SELECT
    c.category         AS course_category,
    COUNT(e.id)        AS total_enrollments,
    SUM(c.monthly_fee) AS estimated_monthly_revenue
FROM courses AS c
INNER JOIN enrollments AS e
    ON e.course_id = c.id
GROUP BY
    c.category
ORDER BY
    estimated_monthly_revenue DESC,
    course_category;


-- ------------------------------------------------------------
-- CONSULTA 8 — Estudiantes inscritos por instructor
-- ------------------------------------------------------------
-- Objetivo     : Contar los estudiantes distintos inscritos en los
--                cursos de cada instructor.
-- Tipo de JOIN : INNER JOIN (courses → enrollments) + GROUP BY
-- Explicación  : COUNT(DISTINCT e.student_id) cuenta a cada estudiante
--                una sola vez aunque siga varios cursos del mismo
--                instructor. El INNER JOIN deja fuera a los instructores
--                sin inscripciones. 'Pending assignment' no se filtra.
-- ------------------------------------------------------------
SELECT
    c.instructor_name            AS instructor_name,
    COUNT(DISTINCT e.student_id) AS enrolled_students
FROM courses AS c
INNER JOIN enrollments AS e
    ON e.course_id = c.id
GROUP BY
    c.instructor_name
ORDER BY
    enrolled_students DESC,
    instructor_name;


-- ------------------------------------------------------------
-- CONSULTA 9 — Inscripciones con student_id huérfano
-- ------------------------------------------------------------
-- Objetivo     : Detectar inscripciones cuyo student_id no corresponde
--                con ninguna fila de students.
-- Tipo de JOIN : LEFT JOIN (enrollments → students)
-- Explicación  : La clave foránea (student_id NOT NULL REFERENCES
--                students(id)) debería impedir los huérfanos, así que
--                se esperan cero filas. Comprobación de solo lectura.
-- ------------------------------------------------------------
SELECT
    e.id              AS enrollment_id,
    e.student_id      AS orphan_student_id,
    e.course_id       AS course_id,
    e.enrollment_date AS enrollment_date
FROM enrollments AS e
LEFT JOIN students AS s
    ON s.id = e.student_id
WHERE s.id IS NULL
ORDER BY
    enrollment_id;


-- ------------------------------------------------------------
-- CONSULTA 10 — Inscripciones con course_id huérfano
-- ------------------------------------------------------------
-- Objetivo     : Detectar inscripciones cuyo course_id no corresponde
--                con ninguna fila de courses.
-- Tipo de JOIN : LEFT JOIN (enrollments → courses)
-- Explicación  : La clave foránea (course_id NOT NULL REFERENCES
--                courses(id)) debería impedir los huérfanos, así que
--                se esperan cero filas. Comprobación de solo lectura.
-- ------------------------------------------------------------
SELECT
    e.id              AS enrollment_id,
    e.course_id       AS orphan_course_id,
    e.student_id      AS student_id,
    e.enrollment_date AS enrollment_date
FROM enrollments AS e
LEFT JOIN courses AS c
    ON c.id = e.course_id
WHERE c.id IS NULL
ORDER BY
    enrollment_id;
