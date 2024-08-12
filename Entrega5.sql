-- 1. Crear una nueva cuenta bancaria.

CREATE OR REPLACE PROCEDURE crear_cuenta_bancaria_cliente(
    IN p_cliente_id INTEGER,
    IN p_numero_cuenta VARCHAR(20),
    IN p_saldo DECIMAL(15, 2),
    IN p_estado VARCHAR(10) DEFAULT 'ACTIVA'
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO cuentas_bancarias (cliente_id, numero_cuenta, saldo, estado)
    VALUES (p_cliente_id, p_numero_cuenta, p_saldo, p_estado);
	RAISE NOTICE 'Cuenta creada exitosamente para el cliente ID % con saldo inicial de %', p_cliente_id, p_saldo;

END;
$$;

CALL crear_cuenta_bancaria_cliente(1, '29857785599', 50000.00);

-- 2. Actualizar la información del cliente

CREATE OR REPLACE PROCEDURE actualizar_informarcion_cliente(
    IN p_cliente_id INTEGER,
    IN p_direccion VARCHAR(300),
    IN p_telefono VARCHAR(20),
    IN p_correo_electronico VARCHAR(300)
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE clientes
    SET direccion = p_direccion,
        telefono = p_telefono,
        correo_electronico = p_correo_electronico
    WHERE cliente_id = p_cliente_id;
	RAISE NOTICE 'Información actualizada para el cliente ID %', p_cliente_id;
END;
$$;

CALL actualizar_informarcion_cliente(1, 'CR 50A 55-88', '2550305', 'PEPITO@gmail.com');

-- 3. Eliminar una cuenta bancaria

CREATE OR REPLACE PROCEDURE eliminar_cuenta_bancaria_cliente(
    IN p_cuenta_id VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM transacciones
    WHERE cuenta_id = v_cuenta_id;

    DELETE FROM cuentas_bancarias
    WHERE cuenta_id = v_cuenta_id;
	RAISE NOTICE 'Cuenta ID % y sus transacciones asociadas han sido eliminadas.', p_cuenta_id;

END;
$$;

CALL eliminar_cuenta_bancaria_cliente('29857785599');


-- 4.Transferir fondos entre cuentas

CREATE OR REPLACE PROCEDURE transferir_fondos_entre_cuentas(
    IN p_cuenta_origen VARCHAR(20),
    IN p_cuenta_destino VARCHAR(20),
    IN p_monto NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta_origen_id INTEGER;
    v_cuenta_destino_id INTEGER;
    v_saldo_origen NUMERIC;
BEGIN

    SELECT cuenta_id, saldo INTO v_cuenta_origen_id, v_saldo_origen
    FROM cuentas_bancarias
    WHERE numero_cuenta = p_cuenta_origen;

    IF v_cuenta_origen_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta bancaria de origen con el número % no existe.', p_cuenta_origen;
    END IF;

    SELECT cuenta_id INTO v_cuenta_destino_id
    FROM cuentas_bancarias
    WHERE numero_cuenta = p_cuenta_destino;

    IF v_cuenta_destino_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta bancaria de destino con el número % no existe.', p_cuenta_destino;
    END IF;

    IF v_saldo_origen < p_monto THEN
        RAISE EXCEPTION 'Fondos insuficientes en la cuenta de origen.';
    END IF;

    UPDATE cuentas_bancarias
    SET saldo = saldo - p_monto
    WHERE cuenta_id = v_cuenta_origen_id;

    UPDATE cuentas_bancarias
    SET saldo = saldo + p_monto
    WHERE cuenta_id = v_cuenta_destino_id;

    INSERT INTO transacciones (cuenta_id, tipo, monto, descripcion)
    VALUES (v_cuenta_origen_id, 'DEBITO', p_monto, 'Transferencia a cuenta ' || p_cuenta_destino);

    INSERT INTO transacciones (cuenta_id, tipo, monto, descripcion)
    VALUES (v_cuenta_destino_id, 'CREDITO', p_monto, 'Transferencia desde cuenta ' || p_cuenta_origen);
	RAISE NOTICE 'Transferencia de % desde la cuenta % a la cuenta % completada.', p_monto, p_cuenta_origen, p_cuenta_destino;

END;
$$;

CALL transferir_fondos_entre_cuentas('29857785599', '29657885593', 60000.00);


-- 5. Agregar una nueva transacción

CREATE OR REPLACE PROCEDURE agregar_transaccion(
    IN p_cuenta_id VARCHAR(20),
    IN p_tipo_transaccion VARCHAR(10),
    IN p_monto NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta_id INTEGER;
    v_saldo_actual NUMERIC;
BEGIN
   
    SELECT cuenta_id, saldo INTO v_cuenta_id, v_saldo_actual
    FROM cuentas_bancarias
    WHERE numero_cuenta = p_cuenta_id;
 
    IF v_cuenta_id IS NULL THEN
        RAISE EXCEPTION 'La cuenta bancaria con el número % no existe.', p_cuenta_id;
    END IF;

    IF p_tipo_transaccion NOT IN ('DEPOSITO', 'RETIRO') THEN
        RAISE EXCEPTION 'Tipo de transacción inválido. Debe ser DEPOSITO o RETIRO.';
    END IF;

    IF p_tipo_transaccion = 'RETIRO' AND v_saldo_actual < p_monto THEN
        RAISE EXCEPTION 'Fondos insuficientes en la cuenta para realizar el retiro.';
    END IF;

    IF p_tipo_transaccion = 'DEPOSITO' THEN
        UPDATE cuentas_bancarias
        SET saldo = saldo + p_monto
        WHERE cuenta_id = v_cuenta_id;
    ELSE
        UPDATE cuentas_bancarias
        SET saldo = saldo - p_monto
        WHERE cuenta_id = v_cuenta_id;
    END IF;

    INSERT INTO transacciones (cuenta_id, tipo, monto, descripcion)
    VALUES (v_cuenta_id, p_tipo_transaccion, p_monto, p_tipo_transaccion || ' de ' || p_monto || ' a la cuenta ' || p_cuenta_id);
	RAISE NOTICE 'Transacción de % realizada en la cuenta ID %.', p_monto, p_cuenta_id;

	
END;
$$;

CALL agregar_transaccion('29857785599', 'DEPOSITO', 80000.00);


-- 6. Calcular el saldo total de todas las cuentas de un cliente

CREATE OR REPLACE PROCEDURE calcular_saldo_total_cliente(
    p_cliente_id INTEGER,
    OUT p_saldo_total NUMERIC(12, 2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    SELECT SUM(saldo) 
	INTO p_saldo_total
    FROM cuentas_bancarias
    WHERE cliente_id = p_cliente_id;
END;
$$;

call calcular_saldo_total_cliente(1, 0);


-- 7. Generar un reporte de transacciones para un rango de fechas

CREATE OR REPLACE FUNCTION generar_reporte_transacciones_cliente(
    p_fecha_inicio DATE,
    p_fecha_fin DATE
)
RETURNS TABLE (
    transaccion_id INTEGER,
    cuenta_id INTEGER,
    tipo_transaccion VARCHAR(10),
    monto NUMERIC,
    descripcion TEXT,
    fecha DATE
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.transaccion_id,
        t.cuenta_id,
        t.tipo_transaccion,
        t.monto,
        t.descripcion,
        t.fecha_apertura
    FROM 
        transacciones t
    WHERE 
        t.fecha BETWEEN p_fecha_inicio AND p_fecha_fin
    ORDER BY 
        t.fecha;
END;
$$;

SELECT * FROM generar_reporte_transacciones_cliente('2024-01-01', '2024-08-31');