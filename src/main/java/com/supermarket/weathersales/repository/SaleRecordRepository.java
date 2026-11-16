package com.supermarket.weathersales.repository;

import com.supermarket.weathersales.domain.SaleRecord;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SaleRecordRepository extends JpaRepository<SaleRecord, Long> {
}
