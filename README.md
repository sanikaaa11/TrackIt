# TrackIt 2.0 🖤

> *Because apparently five separate apps wasn't giving main character energy.*

You have a notes app. A habit tracker. A budget app. A journal. A to-do list.
And somehow you're still a mess.

**TrackIt** puts all of that in one dark, gorgeous Flutter app — with AI that actually tells you why you keep skipping leg day and overspending on food delivery.

---

## What even is this?

A Flutter app for Android that handles your entire life in one place:

| Module | What it does | Vibe |
|---|---|---|
| ✅ **Tasks** | Add tasks, set priorities, get notified, feel productive | CEO behavior |
| 📝 **Notes** | Capture thoughts before they evaporate | Your brain, but reliable |
| 📔 **Journal** | One entry per day. Moods. Photos. Feelings. | Diary but make it digital |
| 💸 **Expenses** | Track where your money goes (spoiler: food) | Broke but self-aware |
| 🔥 **Habits** | Streaks, heatmaps, the whole thing | Discipline arc incoming |

---

## The AI Part (yes, really)

Gemini API is baked into every module because vibes alone won't fix your life:

- **Tasks** — *"Suggest priorities for today"* so you stop staring at your list in existential dread
- **Journal** — Weekly mood summaries every Sunday. A warm paragraph about your week. Therapy-lite.
- **Expenses** — AI looks at your spending and gives you 3–5 suggestions. It will judge you (kindly).
- **Habits** — 30-day pattern analysis. Finds your weak days. Doesn't shame you about them (much).

---

## Badges, because dopamine matters

14 unlockable badges. A few favorites:

- 🥇 **First Step** — Completed your first task. Groundbreaking.
- 💀 **30-Day Warrior** — Maintained a habit for 30 days straight. Are you okay?
- 🧠 **TrackIt Pro** — Used all 5 modules in one day. Certified girlboss/malewife/legend.
- 🤖 **AI Explorer** — Talked to Gemini for the first time. Welcome to the future.

---

## Tech Stack (the nerdy bit)

```
Flutter (Android) • Firebase (Auth + Firestore + Storage)
Hive • Riverpod • GoRouter • Gemini API • Material Design 3
```

- Dark mode by default. Light mode exists but why would you.
- Offline-first. Works without internet. Syncs when you're back.
- Cold start under 2 seconds. Respect your time.

---

## Screenshots

> *(Coming soon — app is still being built, calm down)*

---

## Running Locally

```bash
git clone https://github.com/yourusername/trackit.git
cd trackit
flutter pub get
flutter run
```

> ⚠️ You'll need your own `google-services.json` and Gemini API key.
> These are NOT in the repo because I'm not funding your experiments.

Create a `.env` file:
```
GEMINI_API_KEY=your_key_here
```

---

## Security Stuff

- `google-services.json` is in `.gitignore`. Always was, always will be.
- Firestore rules: your data is yours, nobody else's. Period.
- API keys live in env config, not hardcoded. I'm not a monster.
- ProGuard enabled on release. Code is obfuscated. Good luck reverse engineering this.

---

## Roadmap

- [x] Tasks, Notes, Journal, Expenses, Habits
- [x] Gemini AI across all modules
- [x] Badge system
- [x] Offline-first with Firebase sync
- [ ] iOS version *(not happening, budget reasons)*
- [ ] Google Calendar sync *(V3 problem)*
- [ ] World domination *(in progress)*

---

## The Human Behind This

**Sanikaa Lamkhade** — built this in ~4 weeks while simultaneously learning Hive, Riverpod, and the meaning of life.

---

## License

MIT — use it, fork it, learn from it. Just don't submit it as your own college project. Karma is real.

---

*Built with Flutter, Firebase, Gemini, and an unhealthy amount of determination.*
