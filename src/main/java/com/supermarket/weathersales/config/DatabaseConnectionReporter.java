package com.supermarket.weathersales.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;

/** Al arrancar, deja en el log la prueba de que el backend se conecto a la base de datos. */
@Component
@Order(1)
public class DatabaseConnectionReporter implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DatabaseConnectionReporter.class);

    private final DataSource dataSource;

    public DatabaseConnectionReporter(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            DatabaseMetaData meta = connection.getMetaData();
            log.info("=== CONEXION EXITOSA A LA BASE DE DATOS ===");
            log.info("Motor   : {} {}", meta.getDatabaseProductName(), meta.getDatabaseProductVersion());
            log.info("URL     : {}", meta.getURL());
            log.info("Usuario : {}", meta.getUserName());
        } catch (Exception ex) {
            log.error("No fue posible conectar con la base de datos: {}", ex.getMessage());
            throw ex;
        }
    }
}
