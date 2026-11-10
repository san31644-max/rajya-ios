import SwiftUI

struct LearningView: View {
    @EnvironmentObject var session: AppSession
    @State private var courses: [Value] = []
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        List {
            Section { Notice(text: "Source-based learning and self-assessment. Draft questions and lessons require expert review; these are not official examination papers.") }
            Section {
                NavigationLink { PracticeView() } label: { Label("ප්‍රශ්න පුහුණුව / Practice", systemImage: "checkmark.circle") }
                NavigationLink { ExamLobby() } label: { Label("ආදර්ශ විභාග / Self-assessment", systemImage: "timer") }
                NavigationLink { GuidesView() } label: { Label("කාර්ය පටිපාටි / Procedure guides", systemImage: "list.number") }
            }
            Section("පාඨමාලා") {
                ErrorNotice(message: error)
                if loading { ProgressView() }
                ForEach(courses) { course in
                    NavigationLink { CourseView(id: course["id"].int) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(course["title"].text).font(.headline)
                            Text(course["description"].text).font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: Double(course["completed"].int), total: Double(max(1, course["lessons"].int))).tint(Royal.gold)
                            Text("\(course["completed"].int) / \(course["lessons"].int) lessons completed").font(.caption)
                        }.padding(.vertical, 10)
                    }
                }
                if error != nil { Button("Retry") { Task { await load() } } }
            }
        }.navigationTitle("ඉගෙනුම් මධ්‍යස්ථානය").task { await load() }.refreshable { await load() }
    }
    @MainActor private func load() async { loading = true; defer { loading = false }; do { courses = try await session.request("courses").list; error = nil } catch { self.error = error.localizedDescription } }
}
struct GuidesView: View {
    @EnvironmentObject var session: AppSession
    @State private var guides: [Value] = []
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        List {
            Notice(text: "These procedure guides are review drafts. Confirm responsible officers, required documents and deadlines against original current provisions.")
            ErrorNotice(message: error)
            if loading { ProgressView() }
            ForEach(guides) { guide in
                NavigationLink {
                    List {
                        Text(guide["description"].text)
                        ReviewStatus(status: guide["status"].text)
                        ForEach(Array(guide["steps"].list.enumerated()), id: \.offset) { index, step in
                            Section("\(index + 1). \(step["title"].text)") {
                                Text(step["description"].text)
                                LabeledContent("Responsible officer", value: step["officer"].text)
                                LabeledContent("Documents", value: step["documents"].text)
                                LabeledContent("Time frame", value: step["deadline"].text)
                            }
                        }
                        Section("Original sources") { SourceLinks(sources: guide["sources"].list) }
                    }.navigationTitle(guide["title"].text).navigationBarTitleDisplayMode(.inline)
                } label: { VStack(alignment: .leading, spacing: 8) { Text(guide["title"].text).font(.headline); ReviewStatus(status: guide["status"].text) } }
            }
        }.navigationTitle("කාර්ය පටිපාටි").task {
            loading = true; defer { loading = false }
            do { guides = try await session.request("guides").list } catch { self.error = error.localizedDescription }
        }
    }
}
struct CourseView: View {
    @EnvironmentObject var session: AppSession
    let id: Int
    @State private var course: Value = .null
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        List {
            ErrorNotice(message: error)
            if course == .null && error == nil { ProgressView() }
            if course != .null {
                Section { Text(course["description"].text).foregroundStyle(.secondary) }
                ForEach(course["lessons"].list) { lesson in
                    Section {
                        ReviewStatus(status: lesson["status"].text)
                        Text(lesson["title"].text).font(.title3.bold())
                        Text(lesson["body"].text).textSelection(.enabled).lineSpacing(5)
                        SourceLinks(sources: lesson["sources"].list)
                        Button(lesson["completed"].int > 0 ? "✓ සම්පූර්ණයි" : "කියවා අවසන් කළා") {
                            guard session.user != nil else { session.showLogin = true; return }
                            busy = true
                            Task { defer { busy = false }; do { _ = try await session.request("complete_lesson", body: ["id": .id(lesson["id"].int)]); await load() } catch { self.error = error.localizedDescription } }
                        }.disabled(busy || lesson["completed"].int > 0)
                    }
                }
            }
        }.navigationTitle(course["title"].text).navigationBarTitleDisplayMode(.inline).task { await load() }
    }
    @MainActor private func load() async { do { course = try await session.request("course", query: ["id": String(id)]); error = nil } catch { self.error = error.localizedDescription } }
}
struct PracticeView: View {
    @EnvironmentObject var session: AppSession
    @State private var questions: [Value] = []
    @State private var index = 0
    @State private var result: Value = .null
    @State private var selected: Int?
    @State private var busy = false
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ErrorNotice(message: error)
                if loading { ProgressView() }
                if let question = questions.indices.contains(index) ? questions[index] : nil {
                    Text("\(index + 1) / \(questions.count)").font(.caption).foregroundStyle(.secondary)
                    ReviewStatus(status: question["status"].text)
                    Text(question["prompt"].text).font(.title3.bold())
                    ForEach(Array(question["choices"].list.enumerated()), id: \.offset) { choice, value in
                        Button {
                            guard session.user != nil else { session.showLogin = true; return }
                            busy = true; error = nil
                            Task {
                                defer { busy = false }
                                do { result = try await session.request("learning_answer", body: ["id": .id(question["id"].int), "choice": .id(choice)]); selected = choice }
                                catch { self.error = error.localizedDescription }
                            }
                        } label: {
                            HStack { Text(value.text).multilineTextAlignment(.leading); Spacer(); if result != .null && result["correct_index"].int == choice { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } else if selected == choice { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) } }
                                .padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Royal.paper, in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain).disabled(busy || result != .null)
                    }
                    if result != .null {
                        Text(result["correct"].flag ? "නිවැරදියි!" : "මූලාශ්‍රය නැවත බලමු.").font(.headline)
                        Text(result["explanation"].text)
                        SourceLinks(sources: [result["source"]])
                        Button("ඊළඟ ප්‍රශ්නය") { index = (index + 1) % questions.count; result = .null; selected = nil }.buttonStyle(.borderedProminent)
                    }
                } else if !loading && error == nil { ContentUnavailableView("No practice questions", systemImage: "questionmark.circle") }
            }.padding(22)
        }.navigationTitle("ප්‍රශ්න පුහුණුව").task {
            loading = true; defer { loading = false }
            do { questions = try await session.request("learning_bank").list } catch { self.error = error.localizedDescription }
        }
    }
}
struct ExamLobby: View {
    @EnvironmentObject var session: AppSession
    @State private var count = 10
    @State private var minutes = 15
    @State private var examID: Int?
    @State private var history: [Value] = []
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        Group {
            if session.user == nil { SignInPrompt() }
            else {
                Form {
                    Section { Notice(text: "Timed self-assessment using draft practice questions. Scores are educational, not official qualifications. Answers are saved to your account during the exam.") }
                    Section {
                        Stepper("Questions: \(count)", value: $count, in: 3...30)
                        Stepper("Minutes: \(minutes)", value: $minutes, in: 3...60)
                        ErrorNotice(message: error)
                        Button("Start assessment") {
                            busy = true
                            Task { defer { busy = false }; do { let result = try await session.request("start_exam", body: ["count": .id(count), "minutes": .id(minutes)]); examID = result["id"].int } catch { self.error = error.localizedDescription } }
                        }.disabled(busy)
                    }
                    Section("Recent assessments") {
                        ForEach(history) { exam in
                            Button {
                                examID = exam["id"].int
                            } label: {
                                VStack(alignment: .leading) { Text(exam["finished_at"] == .null ? "Resume assessment" : "View assessment"); Text(exam["started_at"].text).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }.task { await loadHistory() }
            }
        }.navigationTitle("ආදර්ශ විභාග")
            .navigationDestination(isPresented: Binding(get: { examID != nil }, set: { if !$0 { examID = nil; Task { await loadHistory() } } })) { if let examID { ExamView(id: examID) } }
    }
    @MainActor private func loadHistory() async { do { history = try await session.request("workspace")["exams"].list } catch { self.error = error.localizedDescription } }
}
struct ExamView: View {
    @EnvironmentObject var session: AppSession
    let id: Int
    @State private var exam: Value = .null
    @State private var answers: [String: Value] = [:]
    @State private var feedback: Value = .null
    @State private var deadline: Date = .distantFuture
    @State private var seconds = 0
    @State private var submitting = false
    @State private var loaded = false
    @State private var confirmFinish = false
    @State private var saveTask: Task<Void, Never>?
    @State private var error: String?
    @State private var saveStatus = ""
    private var finished: Bool { feedback != .null || (exam != .null && exam["finished_at"] != .null) }
    var body: some View {
        List {
            ErrorNotice(message: error)
            if !loaded { ProgressView() }
            else if finished {
                Section("Result") {
                    Text("\(feedback != .null ? feedback["score"].int : exam["score"].int) / \(exam["questions"].list.count)").font(.largeTitle.bold()).foregroundStyle(Royal.wine)
                    Text("Self-assessment only. Verify answers against the original sources.").font(.caption)
                }
                ForEach(feedback["feedback"].list) { item in
                    Section { Text(item["prompt"].text).font(.headline); Text(item["correct"].flag ? "✓ Correct" : "Review this answer").foregroundStyle(item["correct"].flag ? .green : .orange); Text(item["explanation"].text) }
                }
            } else {
                Section {
                    Label(String(format: "%02d:%02d remaining", seconds / 60, seconds % 60), systemImage: "timer").monospacedDigit().font(.headline)
                    Text(saveStatus).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(exam["questions"].list) { question in
                    Section {
                        Text(question["prompt"].text).font(.headline)
                        ReviewStatus(status: question["status"].text)
                        ForEach(Array(question["choices"].list.enumerated()), id: \.offset) { choice, value in
                            Button {
                                answers[question["id"].text] = .id(choice)
                                saveStatus = "Saving…"
                                let precedingSave = saveTask
                                let snapshot = answers
                                // Preserve write order: an older request must never overwrite a newer answer set.
                                saveTask = Task {
                                    await precedingSave?.value
                                    do {
                                        _ = try await session.request("save_exam_answers", body: ["id": .id(id), "answers": .object(snapshot)])
                                        if answers == snapshot { saveStatus = "Saved to your account" }
                                    } catch { self.error = error.localizedDescription; saveStatus = "Save failed — retry or submit before leaving" }
                                }
                            } label: { HStack { Text(value.text).multilineTextAlignment(.leading); Spacer(); Image(systemName: answers[question["id"].text]?.int == choice ? "checkmark.circle.fill" : "circle") } }
                        }
                    }
                }.disabled(submitting || seconds == 0)
                Button("Submit assessment") { confirmFinish = true }.disabled(submitting)
                if saveStatus.contains("failed") { Button("Retry saving answers") { Task { await saveCurrent() } } }
            }
        }.navigationTitle("Self-assessment").navigationBarTitleDisplayMode(.inline)
            .task {
                do {
                    exam = try await session.request("exam", query: ["id": String(id)])
                    answers = exam["answers"].dictionary; seconds = exam["seconds_left"].int; deadline = .now.addingTimeInterval(Double(seconds)); loaded = true
                    while !Task.isCancelled && !finished {
                        seconds = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                        if seconds == 0 { await finish(); break }
                        try await Task.sleep(for: .seconds(1))
                    }
                } catch is CancellationError {} catch { self.error = error.localizedDescription }
            }
            .confirmationDialog("Submit your answers?", isPresented: $confirmFinish, titleVisibility: .visible) { Button("Submit assessment") { Task { await finish() } } }
    }
    @MainActor private func saveCurrent() async {
        await saveTask?.value
        do { _ = try await session.request("save_exam_answers", body: ["id": .id(id), "answers": .object(answers)]); saveStatus = "Saved to your account"; error = nil } catch { self.error = error.localizedDescription }
    }
    @MainActor private func finish() async {
        guard !submitting && !finished else { return }
        submitting = true; defer { submitting = false }
        await saveTask?.value
        do { feedback = try await session.request("finish_exam", body: ["id": .id(id), "answers": .object(answers)]); error = nil }
        catch { self.error = error.localizedDescription }
    }
}
