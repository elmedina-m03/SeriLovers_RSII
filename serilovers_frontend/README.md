# serilovers_frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

### Environment Setup

**IMPORTANT:** You must create a `.env` file before running the app.

1. Copy the `env.template` file to `.env`:
   ```bash
   cp env.template .env
   ```

2. Configure `API_BASE_URL` in `.env` based on your target platform:
   - **Android Emulator**: `API_BASE_URL=http://10.0.2.2:5149/api`
     - The address `10.0.2.2` maps to the host machine's localhost from the Android emulator
   - **iOS Simulator**: `API_BASE_URL=http://localhost:5149/api`
   - **Real Device (USB/WiFi)**: `API_BASE_URL=http://YOUR_PC_IP:5149/api`
     - Example: `API_BASE_URL=http://192.168.1.50:5149/api`
     - Make sure your firewall allows access

### Resources

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
