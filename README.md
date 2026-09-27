# 🎓 BoardMate - AI Study Companion

BoardMate is a premium Flutter-based educational application specifically designed for 9th-grade students following the **Sindh Board curriculum**. It bridges the gap between traditional learning and modern technology by integrating Google's Gemini AI to provide a personalized tutoring experience.

![App Logo](assets/images/app_logo.png)

## 🚀 Key Features

*   **🤖 AI Tutor (Gemini Integration):** A smart assistant that explains complex topics in both English and Roman Urdu, tailored specifically to the Sindh Board syllabus.
*   **📝 Interactive Quiz Engine:** Test your knowledge with chapter-wise quizzes, real-time scoring, and detailed performance analytics.
*   **📚 Resource Library:** Instant access to curated PDFs and study materials (DOCX/PDF) with an in-app viewer.
*   **📊 Progress Tracking:** Visual metrics and dashboards to monitor learning milestones and subject mastery.
*   **🔔 Real-time Notifications:** Stay updated on new study materials and quiz availability via Firebase Cloud Messaging.
*   **❤️ Favorites System:** Save important resources and quizzes for quick access.

## 🛠️ Tech Stack

*   **Frontend:** Flutter & Dart
*   **Backend:** Firebase (Auth, Firestore, Storage)
*   **AI Engine:** Google Gemini (via `google_generative_ai`)
*   **State Management:** Provider / Clean Architecture
*   **Config:** Firebase Remote Config for dynamic AI system prompts

## ⚙️ Getting Started

### Prerequisites
*   Flutter SDK (v3.10.3 or higher)
*   A Google Gemini API Key
*   A Firebase Project

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/Sohaib1256/Boardmate.git
    ```

2.  **Setup Environment Variables:**
    Create a `.env` file in the root directory and add your Gemini API Key:
    ```env
    GEMINI_API_KEY=your_api_key_here
    ```

3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

4.  **Run the app:**
    ```bash
    flutter run
    ```

---
*Developed with ❤️ for the students of Sindh.*

## 🔗 Let's Connect
[![LinkedIn](https://img.shields.io/badge/LinkedIn-%230077B5.svg?logo=linkedin&logoColor=white)](https://www.linkedin.com/in/sohaib-sheikh-388a9036a/)
