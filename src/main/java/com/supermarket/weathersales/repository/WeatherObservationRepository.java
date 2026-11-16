package com.supermarket.weathersales.repository;

import com.supermarket.weathersales.domain.WeatherObservation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface WeatherObservationRepository extends JpaRepository<WeatherObservation, Long> {

    List<WeatherObservation> findByCityIgnoreCaseOrderByObservationDateDesc(String city);
}
