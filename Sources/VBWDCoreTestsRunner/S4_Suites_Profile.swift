import Foundation
import VBWDCore
import VBWDCoreTestKit

// MARK: - ProfileService Tests

func registerProfileServiceSuites(_ runner: TestRunner) {
    runner.suite("ProfileService (4.0)") { s in

        await s.test("test_fetchProfile_decodesAllFields") {
            let api = SpyAPIClient { path, method, _ in
                if method == .get && path == "/user/profile" {
                    return (200, ProfileFixtures.profileResponseJSON)
                }
                return (404, Data("{\"error\":\"not found\"}".utf8))
            }
            let service = DefaultProfileService(client: api)
            let profile = try await service.fetchProfile()
            s.expectEqual(profile.firstName, "Jane")
            s.expectEqual(profile.lastName, "Doe")
            s.expectEqual(profile.company, "Acme Inc.")
            s.expectEqual(profile.taxNumber, "DE123456789")
            s.expectEqual(profile.phone, "+49 123 456 7890")
            s.expectEqual(profile.addressLine1, "123 Main Street")
            s.expectEqual(profile.addressLine2, "Apt 4B")
            s.expectEqual(profile.city, "Berlin")
            s.expectEqual(profile.postalCode, "10115")
            s.expectEqual(profile.country, "Germany")
        }

        await s.test("test_fetchProfile_networkError_throwsAPIError") {
            let api = SpyAPIClient { _, _, _ in
                return (500, Data("{\"error\":\"server error\"}".utf8))
            }
            let service = DefaultProfileService(client: api)
            await s.expectThrows({
                let _ = try await service.fetchProfile()
            })
        }

        await s.test("test_updateDetails_sendsCorrectBody") {
            let api = SpyAPIClient { path, method, body in
                if method == .put && path == "/user/details" {
                    // Verify the body contains expected keys
                    if let body = body,
                       let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                        let hasFirstName = json["first_name"] != nil
                        let hasLastName = json["last_name"] != nil
                        let hasCompany = json["company"] != nil
                        let hasPhone = json["phone"] != nil
                        let hasCity = json["city"] != nil
                        let hasCountry = json["country"] != nil
                        if hasFirstName && hasLastName && hasCompany && hasPhone && hasCity && hasCountry {
                            return (200, ProfileFixtures.updateResponseJSON)
                        }
                    }
                    return (400, Data("{\"error\":\"bad body\"}".utf8))
                }
                return (404, Data("{\"error\":\"not found\"}".utf8))
            }
            let service = DefaultProfileService(client: api)
            let _ = try await service.updateDetails(ProfileFixtures.fullProfile)
            s.expectEqual(api.calls.count, 1)
            s.expectEqual(api.calls.first?.method, .put)
            s.expectEqual(api.calls.first?.path, "/user/details")
        }

        await s.test("test_changePassword_sendsCorrectBody") {
            let api = SpyAPIClient { path, method, body in
                if method == .post && path == "/user/change-password" {
                    if let body = body,
                       let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                        let hasCurrent = json["currentPassword"] as? String == "OldPass123"
                        let hasNew = json["newPassword"] as? String == "NewPass123!"
                        if hasCurrent && hasNew {
                            return (200, ProfileFixtures.changePasswordSuccessJSON)
                        }
                    }
                    return (400, Data("{\"error\":\"bad body\"}".utf8))
                }
                return (404, Data("{\"error\":\"not found\"}".utf8))
            }
            let service = DefaultProfileService(client: api)
            try await service.changePassword(current: "OldPass123", new: "NewPass123!")
            s.expectEqual(api.calls.count, 1)
            s.expectEqual(api.calls.first?.method, .post)
        }

        await s.test("test_changePassword_serverRejectsWrongCurrent_throwsAPIError") {
            let api = SpyAPIClient { path, method, _ in
                if method == .post && path == "/user/change-password" {
                    return (400, Data("{\"error\":\"Current password is incorrect\"}".utf8))
                }
                return (404, Data("{\"error\":\"not found\"}".utf8))
            }
            let service = DefaultProfileService(client: api)
            await s.expectThrows({
                try await service.changePassword(current: "wrong", new: "NewPass123!")
            })
        }
    }
}

// MARK: - ProfileViewModel Tests

func registerProfileViewModelSuites(_ runner: TestRunner) {
    runner.suite("ProfileViewModel (4.2)") { s in

        await s.test("test_load_setsFormDataFromProfile") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await vm.load()
            let form = await vm.formData
            s.expectEqual(form.firstName, "Jane")
            s.expectEqual(form.lastName, "Doe")
            s.expectEqual(form.company, "Acme Inc.")
            s.expectEqual(form.taxNumber, "DE123456789")
            s.expectEqual(form.phone, "+49 123 456 7890")
            s.expectEqual(form.addressLine1, "123 Main Street")
            s.expectEqual(form.addressLine2, "Apt 4B")
            s.expectEqual(form.city, "Berlin")
            s.expectEqual(form.postalCode, "10115")
            s.expectEqual(form.country, "Germany")
        }

        await s.test("test_load_setsIsLoadingFalseAfterFetch") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await vm.load()
            let loading = await vm.isLoading
            s.expect(!loading, "isLoading should be false after load completes")
        }

        await s.test("test_load_networkError_setsErrorMessage") {
            let service = SpyProfileService()
            service.fetchResult = .failure(APIError.transport(message: "Network down"))
            let vm = await ProfileViewModel(service: service)
            await vm.load()
            let err = await vm.errorMessage
            s.expectNotNil(err, "errorMessage should be set after network error")
        }

        await s.test("test_save_callsUpdateDetailsWithFormData") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await vm.load()
            await vm.save()
            s.expectNotNil(service.updateCalledWith, "updateDetails should have been called")
            s.expectEqual(service.updateCalledWith?.firstName, "Jane")
        }

        await s.test("test_save_success_setsSuccessMessage") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await vm.load()
            await vm.save()
            let msg = await vm.successMessage
            s.expectNotNil(msg, "successMessage should be set on save success")
        }

        await s.test("test_save_failure_setsErrorMessage") {
            let service = SpyProfileService()
            service.updateResult = .failure(APIError.http(status: 500, message: "Server error"))
            let vm = await ProfileViewModel(service: service)
            await vm.load()
            await vm.save()
            let err = await vm.errorMessage
            let success = await vm.successMessage
            s.expectNotNil(err, "errorMessage should be set on save failure")
            s.expectNil(success, "successMessage should be nil on failure")
        }

        await s.test("test_changePassword_emptyFields_returnsValidationError") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await vm.changePassword()
            let err = await vm.passwordError
            s.expectNotNil(err, "passwordError should be set for empty fields")
        }

        await s.test("test_changePassword_mismatch_returnsValidationError") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await MainActor.run {
                vm.passwordData.currentPassword = "OldPass123"
                vm.passwordData.newPassword = "NewPass123!"
                vm.passwordData.confirmPassword = "DifferentPass!"
            }
            await vm.changePassword()
            let err = await vm.passwordError
            s.expectNotNil(err, "passwordError should be set for mismatch")
            s.expect(err?.contains("match") == true, "error should mention 'match'")
        }

        await s.test("test_changePassword_tooShort_returnsValidationError") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await MainActor.run {
                vm.passwordData.currentPassword = "OldPass123"
                vm.passwordData.newPassword = "abc"
                vm.passwordData.confirmPassword = "abc"
            }
            await vm.changePassword()
            let err = await vm.passwordError
            s.expectNotNil(err, "passwordError should be set for short password")
            s.expect(err?.contains("8") == true, "error should mention minimum length")
        }

        await s.test("test_changePassword_valid_callsService") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await MainActor.run {
                vm.passwordData.currentPassword = "OldPass123"
                vm.passwordData.newPassword = "NewPass123!"
                vm.passwordData.confirmPassword = "NewPass123!"
            }
            await vm.changePassword()
            s.expectNotNil(service.changePasswordCalledWith, "service should be called")
            s.expectEqual(service.changePasswordCalledWith?.current, "OldPass123")
            s.expectEqual(service.changePasswordCalledWith?.new, "NewPass123!")
        }

        await s.test("test_changePassword_success_clearsFields") {
            let service = SpyProfileService()
            let vm = await ProfileViewModel(service: service)
            await MainActor.run {
                vm.passwordData.currentPassword = "OldPass123"
                vm.passwordData.newPassword = "NewPass123!"
                vm.passwordData.confirmPassword = "NewPass123!"
            }
            await vm.changePassword()
            let pw = await vm.passwordData
            s.expectEqual(pw.currentPassword, "", "currentPassword should be cleared")
            s.expectEqual(pw.newPassword, "", "newPassword should be cleared")
            s.expectEqual(pw.confirmPassword, "", "confirmPassword should be cleared")
        }
    }
}
