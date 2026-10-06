CREATE TABLE socio(
    id BIGSERIAL PRIMARY KEY,
    club_id BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE,
    telefono VARCHAR(30),
    email VARCHAR(150),
    domicilio VARCHAR(200),
    referencia_familiar VARCHAR(150),

    CONSTRAINT fk_socio_club
        FOREIGN KEY (club_id)
        REFERENCES club(id)
);
