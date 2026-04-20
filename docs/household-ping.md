# **Household Ping: Feature Documentation**

## **1\. Overview**

**Household Ping** is a utility designed to eliminate the friction of "where are you?" texts within a home. It allows family members to request a one-time GPS coordinate from one another for specific context-driven reasons (e.g., timing dinner, safety checks, or meeting up).

## **2\. Core User Experience**

### **A. The Sender (Requesting Location)**

The sender initiates a "Ping" through a high-speed interface:

* **Member Selection:** A carousel of household members with avatars.  
* **The "Why" Context:** Primary preset reasons with icons and pre-written messages, supplemented by a custom option for unique situations.  
  * *Cooking Dinner:* "Starting dinner, how far out are you?"  
  * *Waiting:* "I'm at the spot, where are you?"  
  * *Commute:* "Checking if you've left yet."  
  * *Safety:* "Just making sure you arrived safely."  
  * **Custom Input Field:** An interactive text area for personalized messages. The "Send" action is disabled if this field is selected but left empty.  
* **Request Reciprocity:** To make the interaction an exchange rather than surveillance, sending a ping optionally makes the **sender's** location available to the recipient for the same 5-minute window.  
* **Anti-Spam Cool-down:** A sender is restricted to **one request every 5 minutes per recipient**. The UI shows a "Cool-down active" state with a remaining time indicator.  
* **Ping Timeout & Offline Handling:** Requests are valid for **5 minutes**. The UI distinguishes between:  
  * **Declined:** Recipient actively hit "Decline".  
  * **Timed Out:** No response within 5 minutes.  
  * **Unavailable:** System detects recipient is offline or has no signal (FCM delivery failure).  
* **Result View:** Upon approval, a map card shows the pin and an **Open in Google Maps** button.

### **B. The Recipient (Sharing Location)**

The recipient interacts primarily through actionable notifications:

* **Notification Actions:**  
  1. **Approve:** Shares a one-time coordinate.  
  2. **Approve Always:** Shares the coordinate and adds sender to "Auto-Approve" list.  
  3. **Decline:** Dismisses the request.  
  4. **"Running Late" Shortcuts:** Contextual one-tap replies like "Stuck in traffic" or "Leaving in 5" sent alongside the location approval.  
* **In-App Transparency:** The **Logs** tab shows every single ping that accessed their location.  
  * **Auto-Approve Transparency:** Even if auto-approved, the recipient receives a low-priority notification: *"Location shared automatically with Dad."*

## **3\. Technical Architecture (Firebase)**

### **A. Data Flow**

1. **Request Validation:** App checks for cool-down violations locally.  
2. **Request Entry:** Sender writes to /artifacts/{appId}/public/data/pings.  
3. **Notification Trigger:** A Firebase Cloud Function detects the ping and checks recipient preferences.  
4. **FCM Reliability:** Notifications are sent as **High Priority** messages to bypass OS battery optimizations (Android Doze/iOS Low Power Mode).  
5. **Permission Check:**  
   * **If Auto-Approved:** Updates the ping document with coordinates immediately (if ghostMode is false).  
   * **If Manual:** Dispatches FCM notification.  
6. **Timeout Enforcement:** A TTL index or background task updates pending pings to expired after 5 minutes.

### **B. Data Structure (Firestore)**

**Ping Document:**

{  
  "senderId": "UID\_123",  
  "recipientId": "UID\_456",  
  "reason": "Starting dinner...",  
  "status": "pending | approved | declined | expired | unavailable",  
  "location": { "lat": 40.7128, "lng": \-74.0060, "accuracy": 15 },  
  "timestamp": 1713543200,  
  "respondedAt": 1713543215  
}

## **4\. Privacy & Security Principles**

1. **One-Time "Ping" Logic:** Shares a single GPS snapshot, not a live stream.  
2. **Ghost Mode with Auto-Off:** A master toggle to block all pings. Includes an optional "Auto-Off" timer (e.g., "Ghost for 1 hour") to prevent accidental permanent privacy.  
3. **Recipient Control:** Recipient manages "Auto-Approve" lists and can revoke access via Logs.  
4. **Audit Log:** Permanent record of all location access.

## **5\. UI/UX Highlights**

* **Haptic Feedback:** Physical vibrations for sends and approvals.  
* **Map Privacy:** If GPS accuracy is low, the sender's map displays a **"Radius of Uncertainty"** (a shaded circle) rather than a precise pin to avoid confusion.  
* **Cool-down & Expiration Visuals:** Countdown timers for both the ability to send another ping and the validity of a current request.

## **6\. UI Functional Description**

### **Screen 1: The Command Center (Sender Tab)**

The primary screen is optimized for one-handed, rapid interaction.

* **Header:** Features a global settings gear and the "Ghost Mode" status toggle.  
* **Member Carousel:** avatars of household members. Selecting a member triggers a haptic thrum and updates the context for the ping.  
* **Reason Grid:** Four large, tappable tiles with high-visibility emojis and labels. Tapping a tile pre-fills the message and highlights the "Send" button.  
* **Active Custom Input:** A text area below the grid. As soon as a user begins typing, any selected preset is deselected to ensure the recipient receives exactly what is written.  
* **Dynamic Action Button:** A full-width button at the bottom. It displays "Send Ping" by default, but transforms into a countdown timer (e.g., "Wait 4:12") if the anti-spam cool-down is active.  
* **Persistent Map Card:** If a previous ping was approved recently, a minimized map card remains visible at the bottom of the stack, showing the last known location and a timestamp.

### **Screen 2: Privacy & Management (Recipient Tab)**

This screen focuses on user autonomy and transparency.

* **Trust Management Section:** A clean list of household members with simplified toggle switches. This section clearly states: "These people can see your location automatically."  
* **Detailed Privacy Log:** A vertical list of all recent ping activity. Each entry includes:  
  * Status Icon (Green check for shared, Red X for declined, Grey exclamation for expired).  
  * The specific reason the sender provided.  
  * An "Auto-Approved" badge if the system handled it without a notification.  
  * The exact time of the transaction.  
* **Global Privacy Actions:** A "Clear Log" button and a detailed "Ghost Mode" timer configuration (1h, 4h, Until Tomorrow).

### **Screen 3: Actionable Notification (Interaction Layer)**

The most frequent point of contact for the recipient.

* **Rich Content:** Displays the Sender’s name and the context ("Dad: Starting dinner...").  
* **Mini-Map Snapshot:** A blurred or low-resolution map preview showing the recipient's *own* current location, reminding them exactly what data they are about to share.  
* **Stacked Buttons:** \* **Approve:** High-contrast primary action.  
  * **Approve Always:** Secondary action that modifies database settings for future pings.  
  * **Decline:** Subdued text-only or grey button.  
* **Quick-Response Chips:** Small chips below the main actions for "Stuck in traffic" or "Leaving now," allowing a location share \+ text reply in a single tap.