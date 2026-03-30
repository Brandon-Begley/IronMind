# 💪 IronMind - AI-Powered All-in-One Fitness Platform

**IronMind** is a comprehensive Flutter-based fitness tracking application designed for serious lifters. Track workouts, monitor personal records, manage nutrition, and analyze your wellness all in one beautiful, offline-first app.

## 🎯 Features

### 🏋️ **Workout Tracking**
- **Smart Routine Management**: Create custom routines or import from CSV files
- **Routine-Based Logging**: Select a routine to auto-populate exercises (no more manual entry!)
- **Real-time Exercise Tracking**: Log weight, reps, and sets with intuitive UI
- **Rest Timer**: Customizable rest periods (60s, 90s, 120s, 180s, 240s, 300s)
- **Estimated 1RM Calculation**: Real-time 1RM estimates using the Epley formula
- **Workout History**: View and manage past workouts

### 🏆 **Personal Records (PRs)**
- **Automatic PR Detection**: App recognizes new personal records across ANY exercise
- **PR History**: See when your last PR was for each lift ("2 weeks ago", "3 days ago", etc.)
- **Smart Notifications**: Get instant feedback when you hit a new PR
- **Exercise Support**: Bench Press, Deadlift, Squat (SBD) + any custom exercise
- **Offline Storage**: PRs save locally and sync when you're back online

### 📊 **Dashboard**
- **Quick Stats**: Weekly sessions, volume, and key metrics at a glance
- **Charts**: Visual progress tracking for your lifts
- **Personal Records Display**: Quick view of your best lifts
- **Connection Status**: Real-time server connection indicator

### 🍔 **Nutrition Tracking**
- **Meal Logging**: Track calories, protein, carbs, and fat
- **Food Search**: Built-in food database via Open Food Facts
- **Daily Totals**: See macros and calories for the day
- **Customizable Targets**: Set your own calorie and macro goals

### 💚 **Wellness**
- **Bodyweight Tracking**: Monitor weight trends over time
- **Body Measurements**: Track chest, arms, waist, etc.
- **Health Metrics**: Sleep, stress, and mood tracking
- **Visual Trends**: Charts showing progress and regressions

### 👤 **Lifter Profile**
- **Profile Setup**: Configure experience level, training style, and goals
- **Standard Lifts**: Store your current lifts (Squat, Bench, Deadlift, OHP)
- **Body Stats**: Track bodyweight and measurements
- **Goal Setting**: Peak strength, hypertrophy, endurance goals

### 🤖 **AI Assistant**
- **Workout Generation**: Get AI-suggested workouts based on your preferences
- **Nutrition Plans**: AI-generated meal plans based on your goals
- **Smart Recommendations**: Personalized training suggestions

## 🚀 Getting Started

### Prerequisites
- Flutter 3.41.5+
- Dart 3.11.3+
- Chrome (for web testing)

### Installation

```bash
# Clone the repository
git clone https://github.com/Brandon-Begley/IronMind.git
cd IronMind

# Install dependencies
flutter pub get

# Run on Chrome (web)
flutter run -d chrome

# Run on other platforms
flutter run -d windows
flutter run -d ios
flutter run -d android
```

### CSV Import Format

Import routines from CSV with this format:

```csv
Exercise,Primary,Secondary
Back Squat,Quads,
Leg Press,Quads,Glutes
Romanian Deadlift,Hamstrings,Lower Back
Leg Curl,Hamstrings,
Calf Raise,Calves,
```

Steps:
1. Go to **Workout** → **Routines**
2. Click the **Upload** button
3. Select your CSV file
4. Routine is automatically created!

## 📸 Screenshots

### Dashboard
Track all your key metrics at a glance - sessions, volume, PRs, and wellness data.

### Workout Logging
Simple, intuitive exercise and set tracking with routine-based pre-filling.

### PR Tracking
Automatic PR detection with history showing when your last PR was for each exercise.

### Nutrition
Track macros and calories easily with food database search.

### 1RM Calculator
Real-time 1RM estimation using the Epley formula.

## 🔧 Architecture

### Tech Stack
- **Framework**: Flutter 3.41.5
- **Language**: Dart 3.11.3
- **State Management**: StatefulWidget
- **Storage**: SharedPreferences (local), HTTP (server sync)
- **Networking**: http package
- **Charts**: fl_chart
- **File Handling**: file_picker, csv packages
- **UI**: Google Fonts, Material Design

### Project Structure
```
lib/
├── main.dart                 # App entry point & navigation
├── theme.dart               # Color scheme & theme config
├── screens/                 # UI screens
│   ├── dashboard_screen.dart
│   ├── workout_screen.dart
│   ├── nutrition_screen.dart
│   ├── wellness_screen.dart
│   └── profile_screen.dart
├── services/                # Backend services
│   ├── api_service.dart     # Server/local storage API
│   └── csv_service.dart     # CSV parsing & export
└── widgets/                 # Reusable components
    └── common.dart
```

## 🎨 Design

**Theme**: Dark mode with blue accent color
- **Primary**: `#0A0A0B` (Dark background)
- **Accent**: `#47B4FF` (Blue)
- **Success**: `#47FF8A` (Green)
- **Alert**: `#FF4747` (Red)

**Typography**: Bebas Neue (headers), DM Sans (body), DM Mono (data)

## 📱 Platforms

Currently supports:
- ✅ **Web** (Chrome)
- ✅ **Windows** Desktop
- 🔄 **iOS** (In progress)
- 🔄 **Android** (In progress)

## 🔌 API Integration

### Default Server
```
http://10.0.20.93:3000
```

### Endpoints
- `GET /api/logs` - Fetch workout logs
- `POST /api/logs` - Save workout
- `GET /api/prs` - Fetch PRs
- `POST /api/prs` - Save PR
- `GET /api/progress/{exercise}` - Get exercise progress
- `GET /api/wellness` - Fetch wellness data
- `POST /api/wellness` - Save wellness data
- `POST /api/generate` - Generate workout (AI)
- `POST /api/nutrition/generate` - Generate meal plan (AI)

### Offline Mode
- All data persists locally via SharedPreferences
- App syncs with server when available
- No data loss when offline

## 🛠 Development

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
# Web
flutter build web

# Windows
flutter build windows

# iOS
flutter build ios

# Android
flutter build apk
```

### Hot Reload
During development, use `r` to hot reload or `R` to hot restart.

## 🐛 Known Issues

- Font rendering on web may show warnings (doesn't affect functionality)
- file_picker desktop platform warnings on non-web targets
- Server sync requires internet connectivity

## 📝 Roadmap

- [ ] Apple Health integration
- [ ] Google Fit integration
- [ ] Advanced analytics & insights
- [ ] Social features (compare lifts with friends)
- [ ] Video form analysis
- [ ] Injury prevention recommendations
- [ ] Custom exercise library

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Brandon Begley**
- GitHub: [@Brandon-Begley](https://github.com/Brandon-Begley)
- Project: [IronMind](https://github.com/Brandon-Begley/IronMind)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Open Food Facts for the food database
- All the lifters who inspire better training

---

**Stay strong. Keep grinding. 💪**
