//
//  LocationAuthorizationManager.swift
//  WiFi Check (tvOS)
//
//  CoreLocation authorization is required for NEHotspotNetwork.fetchCurrent()
//  to return a non-nil result on tvOS.

import CoreLocation
import Foundation

class LocationAuthorizationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationAuthorizationManager()
    private let manager = CLLocationManager()
    private(set) var status: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        status = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }
}
