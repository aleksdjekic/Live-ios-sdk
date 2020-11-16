//
//  RestApi+User.swift
//  
//
//  Created by Sacha on 21/07/2020.
//

import Foundation
import Combine
import Networking

extension RestApi: UserRepository {
	
	public func signup(email: Email, password: Password, firstname: String, lastname: String) -> AnyPublisher<User, SignupError> {
		post("/auth/register",
				 params: [
					"email": email,
					"password": password,
					"first_name": firstname,
					"last_name": lastname,
					"username": firstname])
			.map { (user: JSONUser) -> User in
				return user.toUser()
			}
			.mapError { $0.toSignupError() }
			.eraseToAnyPublisher()
	}
	
	public func login(email: String, password: String) -> AnyPublisher<User, LoginError> {
		authenticationToken = nil
		return post("/auth/login", params: ["email": email, "password": password])
			.map { [unowned self] (jsonUser: JSONUser) -> User in
				self.authenticationToken = jsonUser.authToken
				return jsonUser.toUser()
			}
			.mapError { $0.toLoginError() }
			.eraseToAnyPublisher()
	}
	
	public func fetch(user: User) -> AnyPublisher<User, Error> {
		return get("/me").map { (jsonUser: JSONUser) -> User in
			return jsonUser.toUser()
		}.eraseToAnyPublisher()
	}
	
	public func editUser(firstname: String?, lastname: String?) -> AnyPublisher<Void, EditUserError> {
		var params = [String: AnyHashable]()
		if let firstname = firstname {
			params["first_name"] = firstname
		} else if let lastname = lastname {
			params["last_name"] = lastname
		}
		return patch("/me", params: params)
			.map { (_: JSONUser) -> Void in }
			.mapError { $0.toEditUserError() }
			.eraseToAnyPublisher()
	}
}

private extension Error {
	func toSignupError() -> SignupError {
		return SignupError.unknown
	}
}

private extension Error {
	func toLoginError() -> LoginError {
		if let networkingError = self as? NetworkingError {
			if networkingError.code == 400 {
				if let jsonError = networkingError.jsonPayload as? [String: Any],
					 jsonError["error_type"] as? String == "WrongArguments" {
					return LoginError.wrongCredentials
				}
			}
		}
		return LoginError.unknown
	}
}

typealias ID = String

extension JSONUser: NetworkingJSONDecodable {}

struct JSONUser: Decodable {
	
	let id: ID
	let firstname: String
	let lastname: String
	let email: Email
	let username: String
	let isVerified: Bool
	let isStaff: Bool
	let authToken: String?
	let hasAnsweredSurvey: Bool
	let avatarUrl: String?
	
	enum CodingKeys: String, CodingKey {
		case id
		case first_name
		case last_name
		case email
		case username
		case profile_image
		case is_verified
		case is_staff
		case auth_token
		case is_survey_attempted
	}
	
	enum ProfileImageKeys: String, CodingKey {
		case image
	}
	
	enum ImageKeys: String, CodingKey {
		case small
	}
	
	init(from decoder: Decoder) throws {
		let values = try decoder.container(keyedBy: CodingKeys.self)
		id = try values.decode(String.self, forKey: .id)
		firstname = try values.decode(String.self, forKey: .first_name)
		lastname = try values.decode(String.self, forKey: .last_name)
		email = try values.decode(String.self, forKey: .email)
		username = try values.decode(String.self, forKey: .username)
		isVerified = try values.decode(Bool.self, forKey: .is_verified)
		isStaff = try values.decode(Bool.self, forKey: .is_staff)
		authToken = try? values.decode(String.self, forKey: .auth_token)
		hasAnsweredSurvey = try values.decode(Bool.self, forKey: .is_survey_attempted)
		if let profileImageValues = try? values.nestedContainer(keyedBy: ProfileImageKeys.self, forKey: .profile_image) {
			let imageValues = try profileImageValues.nestedContainer(keyedBy: ImageKeys.self, forKey: .image)
			avatarUrl = try imageValues.decode(String.self, forKey: .small)
		} else {
			avatarUrl = nil
		}
	}
}

extension JSONUser {
	func toUser() -> User {
		return User(firstname: firstname, lastname: lastname, email: email, username: username, hasAnsweredSurvey: hasAnsweredSurvey, avatarUrl: avatarUrl)
	}
}

private extension Error {
	func toEditUserError() -> EditUserError {
		return EditUserError.unknown
	}
}