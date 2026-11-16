package com.supermarket.weathersales.web;

import com.supermarket.weathersales.domain.WeatherObservation;
import com.supermarket.weathersales.repository.WeatherObservationRepository;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api/weather")
public class WeatherController {

    private final WeatherObservationRepository repository;

    public WeatherController(WeatherObservationRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<WeatherObservation> list(@RequestParam(required = false) String city) {
        if (city == null || city.isBlank()) {
            return repository.findAll();
        }
        return repository.findByCityIgnoreCaseOrderByObservationDateDesc(city);
    }

    @PostMapping
    public ResponseEntity<WeatherObservation> create(@Valid @RequestBody WeatherObservation observation) {
        observation.setId(null);
        WeatherObservation saved = repository.save(observation);
        return ResponseEntity.created(URI.create("/api/weather/" + saved.getId())).body(saved);
    }
}
