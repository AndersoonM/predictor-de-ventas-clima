package com.supermarket.weathersales.repository;

import com.supermarket.weathersales.domain.Product;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<Product, Long> {
}
