package com.supermarket.weathersales.config;

import com.supermarket.weathersales.domain.Product;
import com.supermarket.weathersales.repository.ProductRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.List;

/** Carga productos de ejemplo la primera vez, para comprobar escritura y lectura en la BD. */
@Component
@Order(2)
public class DataSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    private final ProductRepository products;

    public DataSeeder(ProductRepository products) {
        this.products = products;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (products.count() > 0) {
            log.info("Productos ya existentes: {} (no se cargan datos de ejemplo)", products.count());
            return;
        }
        products.saveAll(List.of(
                new Product("Helado de vainilla 1L", "Helados", new BigDecimal("14900")),
                new Product("Gaseosa 1.5L", "Bebidas frias", new BigDecimal("5200")),
                new Product("Chocolate caliente 250g", "Bebidas calientes", new BigDecimal("9800")),
                new Product("Sopa instantanea", "Sopas", new BigDecimal("3400")),
                new Product("Paraguas plegable", "Hogar", new BigDecimal("27000")),
                new Product("Bloqueador solar 120ml", "Cuidado personal", new BigDecimal("38500"))
        ));
        log.info("Se cargaron {} productos de ejemplo", products.count());
    }
}
