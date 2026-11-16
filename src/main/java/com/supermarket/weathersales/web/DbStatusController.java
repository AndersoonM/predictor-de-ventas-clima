package com.supermarket.weathersales.web;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/** Endpoint de evidencia: consulta directa a la base de datos que corre en Floci (RDS). */
@RestController
@RequestMapping("/api/db")
public class DbStatusController {

    private final JdbcTemplate jdbc;

    public DbStatusController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> status() {
        Map<String, Object> body = new LinkedHashMap<>();
        try {
            body.put("status", "UP");
            body.put("database", jdbc.queryForObject("select current_database()", String.class));
            body.put("user", jdbc.queryForObject("select current_user", String.class));
            body.put("version", jdbc.queryForObject("select version()", String.class));
            body.put("serverTime", jdbc.queryForObject("select now()::text", String.class));
            return ResponseEntity.ok(body);
        } catch (DataAccessException ex) {
            body.clear();
            body.put("status", "DOWN");
            body.put("error", ex.getMostSpecificCause().getMessage());
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(body);
        }
    }
}
