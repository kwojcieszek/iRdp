import Testing
@testable import IRdpConfiguration

struct PasswordHasherTests {
    @Test func verifiesMatchingPassword() {
        let hash = PasswordHasher.makeHash(for: "correct horse", iterations: 1000)
        #expect(PasswordHasher.verify("correct horse", against: hash))
        #expect(!PasswordHasher.verify("wrong horse", against: hash))
    }

    @Test func usesRandomSalt() {
        let first = PasswordHasher.makeHash(for: "same", iterations: 1000)
        let second = PasswordHasher.makeHash(for: "same", iterations: 1000)
        #expect(first.salt != second.salt)
        #expect(first.hash != second.hash)
    }

    @Test func rejectsCorruptedHash() {
        let corrupted = PasswordHash(salt: "%%%", iterations: 1000, hash: "%%%")
        #expect(!PasswordHasher.verify("anything", against: corrupted))
    }
}
