import SwiftUI
import PhotosUI
import CoreData

struct VehicleFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var vehicle: Vehicle?

    @State private var nickname = ""
    @State private var make = ""
    @State private var model = ""
    @State private var year = ""
    @State private var trim = ""
    @State private var engine = ""
    @State private var vin = ""
    @State private var plate = ""
    @State private var notes = ""
    @State private var currentMileage = ""
    @State private var isDecodingVIN = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let data = photoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            EmptyStateView("Add Photo", systemImage: "camera")
                                .frame(height: 180)
                        }
                    }
                }

                Section("Basics") {
                    TextField("Nickname", text: $nickname, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Year", text: $year)
                        .keyboardType(.numberPad)
                    TextField("Make", text: $make, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Model", text: $model, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Trim", text: $trim, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Engine", text: $engine, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Identifiers") {
                    TextField("VIN", text: $vin, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("Plate", text: $plate, axis: .vertical)
                        .lineLimit(1...3)
                    Button(isDecodingVIN ? "Decoding..." : "Decode VIN") {
                        decodeVIN()
                    }
                    .disabled(isDecodingVIN)
                }

                Section("Tracking") {
                    TextField("Current Mileage", text: $currentMileage)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 120)
                }
            }
            .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if saveVehicle() {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear(perform: loadVehicle)
            .onChange(of: selectedPhotoItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }

    private func loadVehicle() {
        guard let vehicle else { return }
        nickname = vehicle.nickname ?? ""
        make = vehicle.make ?? ""
        model = vehicle.model ?? ""
        year = vehicle.year > 0 ? String(vehicle.year) : ""
        trim = vehicle.trim ?? ""
        engine = vehicle.engine ?? ""
        vin = vehicle.vin ?? ""
        plate = vehicle.plate ?? ""
        notes = vehicle.notes ?? ""
        currentMileage = Formatters.mileageText(vehicle.latestKnownMileage)
        photoData = vehicle.photoData
    }

    @discardableResult
    private func saveVehicle() -> Bool {
        let target = vehicle ?? Vehicle(context: viewContext)
        if vehicle == nil {
            target.id = UUID()
            target.createdAt = Date()
        }
        target.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        target.make = make.trimmingCharacters(in: .whitespacesAndNewlines)
        target.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        target.year = Int16(year) ?? 0
        target.trim = trim.trimmingCharacters(in: .whitespacesAndNewlines)
        target.engine = engine.trimmingCharacters(in: .whitespacesAndNewlines)
        target.vin = vin.trimmingCharacters(in: .whitespacesAndNewlines)
        target.plate = plate.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newMileage = Formatters.parseMileage(currentMileage) {
            guard newMileage >= target.latestKnownMileage else {
                AppErrorCenter.shared.message = "Mileage cannot be lower than the current value."
                return false
            }
            target.currentMileage = newMileage
        }
        target.photoData = photoData

        do {
            try viewContext.save()
            AppFeedbackCenter.shared.show("Vehicle saved")
            return true
        } catch {
            AppErrorCenter.shared.message = error.localizedDescription
            return false
        }
    }

    private func decodeVIN() {
        let cleanedVIN = VINDecoder.sanitize(vin)
        guard !cleanedVIN.isEmpty else {
            AppErrorCenter.shared.message = "Enter a VIN first."
            return
        }
        vin = cleanedVIN
        isDecodingVIN = true

        Task {
            do {
                let decoded = try await VINDecoder.decode(vin: cleanedVIN)
                await MainActor.run {
                    if let year = decoded.year, year > 0 {
                        self.year = String(year)
                    }
                    if let make = decoded.make { self.make = make }
                    if let model = decoded.model { self.model = model }
                    if let trim = decoded.trim { self.trim = trim }
                    if let engine = decoded.engine { self.engine = engine }
                    self.isDecodingVIN = false
                    AppFeedbackCenter.shared.show("VIN decoded")
                }
            } catch {
                await MainActor.run {
                    self.isDecodingVIN = false
                    AppErrorCenter.shared.message = error.localizedDescription
                }
            }
        }
    }
}
