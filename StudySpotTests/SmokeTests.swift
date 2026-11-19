//
//  SmokeTests.swift
//  StudySpotTests
//

import Testing
@testable import iOSApprenticeProject

struct SmokeTests {
    @Test func eventCategoryChipTitles() {
        #expect(EventCategory.studyGroup.chipTitle == "STUDY GROUP")
        #expect(EventCategory.allCases.count == 4)
    }
}
