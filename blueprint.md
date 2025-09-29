# E-commerce App Blueprint

## Overview

A Flutter e-commerce application that allows users to browse products, view product details, and add items to a shopping cart. The application will be designed with a clean and modern user interface, following Material Design principles.

## Style and Design

*   **Theme:** Modern and visually appealing theme with a consistent color scheme and typography.
*   **Navigation:** A persistent bottom navigation bar for switching between Home, Categories, and Profile.
*   **Layout:** Clean and organized layouts with a focus on product presentation.

## Features

*   **Home Screen:** Displays featured products and categories.
*   **Categories Screen:** Displays a list of all product categories.
*   **Category List Screen:** Displays a list of products within a specific category.
*   **Product Detail Screen:** Shows the details of a single product.
*   **Profile Screen:** A placeholder for user profile information.
*   **Login Screen:** A screen for users to log in or sign up, with options for email/password and Google sign-in.

## Current Plan

### Iteration 1: E-commerce App Foundation

The initial version of the app focused on setting up the basic structure and navigation.

**Steps:**

1.  **Set up the project:** Added `go_router`, `google_fonts`, and `provider` dependencies.
2.  **Create data models:** Defined `Product` and `Category` classes.
3.  **Create placeholder data:** Created sample data for products and categories.
4.  **Set up routing:** Used `go_router` to manage navigation between screens, including a bottom navigation bar.
5.  **Create screens:** Implemented the Home, Categories, Category List, Product Detail, and Profile screens.
6.  **Implement the theme:** Created a custom theme in `lib/main.dart`.
7.  **Update main.dart:** Integrated the router and theme.

### Iteration 2: Login/Signup Screen

This iteration focused on creating and integrating a user authentication screen.

**Steps:**

1.  **Create Login Screen:** A new screen `lib/screens/login_screen.dart` was created based on the provided design. It includes fields for email and password, a "Sign In" button, a "Sign in with Google" button, and a link to a sign-up page.
2.  **Update Routing:** The `lib/router.dart` file was modified to make the `/login` route the initial location for the application.
3.  **Integrate Screen:** The new login screen is now the first screen the user sees when opening the app.
