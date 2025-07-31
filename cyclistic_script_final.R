# ========================================
# 🚲 Cyclistic Case Study – Final R Script
# Google Data Analytics Certificate Project
# ========================================

# --- Load Packages ---
library(tidyverse)
library(lubridate)
library(scales)

# --- Create images folder if it doesn't exist ---
if (!dir.exists("images")) dir.create("images")

# --- Load and Standardize Datasets ---
divvy_2019 <- read_csv("data/Divvy_Trips_2019_Q1.csv") %>%
  rename(
    ride_id = trip_id,
    rideable_type = bikeid,
    started_at = start_time,
    ended_at = end_time,
    start_station_name = from_station_name,
    start_station_id = from_station_id,
    end_station_name = to_station_name,
    end_station_id = to_station_id,
    member_casual = usertype
  ) %>%
  mutate(
    rideable_type = "docked_bike",
    member_casual = ifelse(member_casual == "Subscriber", "member", "casual"),
    ride_id = as.character(ride_id)
  )

divvy_2020 <- read_csv("data/Divvy_Trips_2020_Q1.csv")

columns <- c("ride_id", "rideable_type", "started_at", "ended_at",
             "start_station_name", "start_station_id",
             "end_station_name", "end_station_id", "member_casual")

divvy_2019 <- divvy_2019 %>% select(all_of(columns))
divvy_2020 <- divvy_2020 %>% select(all_of(columns))

# --- Merge, Clean, and Format Data in One Go ---
all_trips <- bind_rows(divvy_2019, divvy_2020) %>%
  mutate(
    started_at = as.POSIXct(started_at, format = "%Y-%m-%d %H:%M:%S"),
    ended_at = as.POSIXct(ended_at, format = "%Y-%m-%d %H:%M:%S"),
    ride_length = as.numeric(difftime(ended_at, started_at, units = "mins")),
    member_casual = tolower(trimws(member_casual)),
    date = as.Date(started_at),
    month = format(date, "%m"),
    day = format(date, "%d"),
    year = format(date, "%Y"),
    weekday_num = lubridate::wday(date, week_start = 7),
    weekday = factor(weekday_num,
                     levels = 1:7,
                     labels = c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"),
                     ordered = TRUE),
    ride_minutes = ride_length,
    casual_cost = case_when(
      member_casual == "casual" ~ 1 + 0.18 * ride_minutes,
      TRUE ~ 0
    )
  ) %>%
  filter(start_station_name != "HQ QR", ride_length >= 0, ride_length <= 1440)

# ===============================
# 📊 VISUALIZATIONS
# ===============================

# Helper function for saving plots
ggsave_img <- function(plot, filename, width = 10, height = 6, dpi = 100) {
  ggsave(filename = file.path("images", filename), plot = plot, width = width, height = height, dpi = dpi, bg = "white")
}

# Custom theme
custom_theme <- theme_minimal() +
  theme(
    plot.title = element_text(size = 26, face = "bold"),
    axis.title.x = element_text(size = 22, face = "bold"),
    axis.title.y = element_text(size = 22, face = "bold"),
    axis.text.x = element_text(size = 24),
    axis.text.y = element_text(size = 24),
    legend.title = element_text(size = 14),
    legend.text = element_text(size = 12)
  )

# --- Visual 1: Ride Length Distribution by Rider Type (Faceted) ---
p1 <- all_trips %>%
  filter(ride_length <= 90) %>%
  ggplot(aes(x = ride_length, fill = member_casual)) +
  geom_histogram(binwidth = 5, color = "white") +
  facet_wrap(~member_casual, scales = "free_y") +
  scale_fill_manual(values = c("casual" = "darkorange", "member" = "steelblue")) +
  labs(
    title = "Ride Length Distribution by Rider Type (0–90 min)",
    x = "Ride Length (minutes)",
    y = "Number of Rides",
    fill = "Rider Type"
  ) + custom_theme

ggsave_img(p1, "ride_length_distribution_faceted.png")

# --- Visual 2 Pie Chart: Casual Rides Over vs Under 45 Minutes ---

casual_trips <- all_trips %>% filter(member_casual == "casual")

casual_ride_stats <- casual_trips %>%
  mutate(ride_duration_cat = ifelse(ride_length > 45, "Over 45 minutes", "45 minutes or less")) %>%
  count(ride_duration_cat) %>%
  mutate(
    percentage = round(n / sum(n) * 100, 1),
    label = paste0(percentage, "%")
  )

pie_chart <- ggplot(casual_ride_stats, aes(x = "", y = n, fill = ride_duration_cat)) +
  geom_col(width = 1, color = "white") +
  coord_polar(theta = "y") +
  geom_text(
    aes(label = label),
    position = position_stack(vjust = 0.5),
    size = 11,
    color = "white",
    fontface = "bold"
  ) +
  scale_fill_manual(
    values = c("45 minutes or less" = "#90A4AE", "Over 45 minutes" = "#FF7043")
  ) +
  labs(
    title = "Casual Rides Over vs. Under 45 Minutes",
    fill = "Ride Duration"
  ) +
  theme_void() +
  theme(
    plot.title = element_text(size = 20, face = "bold"),
    legend.title = element_text(size = 18),
    legend.text = element_text(size = 17),
    legend.position = "right",
    plot.margin = margin(10, 30, 10, 10)
  )

ggsave("images/casual_long_ride_pie_v2.png", plot = pie_chart, width = 8, height = 6, dpi = 100, bg = "white")

# --- Visual 3: Casual Ride Cost Distribution ---
casual_data <- all_trips %>%
  filter(member_casual == "casual", !is.na(casual_cost), casual_cost > 0)

if (nrow(casual_data) == 0) {
  png("images/casual_cost_distribution.png", width = 1000, height = 600)
  plot.new()
  text(0.5, 0.5, "No data available for casual ride costs")
  dev.off()
} else {
  max_count <- max(hist(casual_data$casual_cost[casual_data$casual_cost <= 30], plot = FALSE)$counts, na.rm = TRUE)
  p6 <- ggplot(casual_data, aes(x = casual_cost)) +
    geom_histogram(binwidth = 1, fill = "darkorange", color = "white") +
    coord_cartesian(xlim = c(0, 30)) +
    labs(title = "Distribution of Casual Ride Costs (0–30$)",
         x = "Cost per Ride ($)", y = "Number of Rides") +
    geom_vline(xintercept = 11.99, linetype = "dashed", color = "steelblue") +
    annotate("text", x = 13, y = max_count * 0.9, label = "Membership Cost", hjust = 0, color = "steelblue") +
    custom_theme

  ggsave_img(p6, "casual_cost_distribution.png", width = 12)
}

# --- Visual 4: Monthly Casual Spending (No Dashed Line) ---

monthly_spending_clean <- all_trips %>%
  filter(member_casual == "casual") %>%
  mutate(month = format(started_at, "%Y-%m")) %>%
  group_by(month) %>%
  summarise(total_casual_cost = sum(casual_cost), .groups = "drop")

p_agg_spend <- ggplot(monthly_spending_clean, aes(x = month, y = total_casual_cost)) +
  geom_col(fill = "darkorange") +
  labs(title = "The Size of the Casual Spend Pool",
       x = "Month", y = "Total Casual Spend ($)") +
  custom_theme

ggsave_img(p_agg_spend, "casual_total_spend_noline.png", width = 12)

# --- Visual 5: Actual vs Hypothetical Spend (Per-User Comparison) ---

# Prepare data
per_user_cost <- all_trips %>%
  filter(member_casual == "casual") %>%
  mutate(month = format(started_at, "%Y-%m")) %>%
  group_by(month) %>%
  summarise(
    actual_spend = sum(casual_cost),
    unique_users = n_distinct(ride_id)  # Note: conservative proxy; if you have user_id, use that
  ) %>%
  mutate(
    hypothetical_member_spend = unique_users * 11.99,
    spend_gap = actual_spend - hypothetical_member_spend
  )

# Reshape for plotting
spend_compare_long <- per_user_cost %>%
  pivot_longer(cols = c(actual_spend, hypothetical_member_spend), names_to = "type", values_to = "value")

# Create plot
p_compare_spend <- ggplot(spend_compare_long, aes(x = month, y = value, fill = type)) +
  geom_col(position = "dodge") +
  scale_fill_manual(
    values = c("actual_spend" = "darkorange", "hypothetical_member_spend" = "steelblue"),
    labels = c("Actual Spend", "If Members")
  ) +
  labs(
    title = "What Casual Riders Paid vs. What They Could Have Paid",
    x = "Month", y = "Total Spend ($)", fill = "Spending Type"
  ) +
  custom_theme

# Save the image
ggsave("images/casual_actual_vs_member_spend.png", plot = p_compare_spend, width = 12, height = 6, dpi = 100, bg = "white")

# --- Visual 6: Average Duration by Weekday ---
weekday_duration <- all_trips %>%
  group_by(member_casual, weekday) %>%
  summarise(avg_duration = mean(ride_length), .groups = "drop")

p4 <- ggplot(weekday_duration, aes(x = weekday, y = avg_duration, fill = member_casual)) +
  geom_col(position = "dodge") +
  labs(title = "Average Ride Duration by Weekday and Rider Type",
       x = "Day of the Week", y = "Average Ride Duration (minutes)", fill = "Rider Type") +
  scale_fill_manual(values = c("member" = "steelblue", "casual" = "darkorange")) +
  custom_theme

ggsave_img(p4, "avg_duration_weekday.png", width = 11)

# --- Visual 7: Ride Frequency by Weekday ---
weekday_freq <- all_trips %>%
  group_by(member_casual, weekday) %>%
  summarise(number_of_rides = n(), .groups = "drop")

p3 <- ggplot(weekday_freq, aes(x = weekday, y = number_of_rides, fill = member_casual)) +
  geom_col(position = "dodge") +
  labs(title = "Ride Frequency by Day of Week and User Type",
       x = "Day of the Week", y = "Number of Rides", fill = "Rider Type") +
  scale_fill_manual(values = c("member" = "steelblue", "casual" = "darkorange")) +
  custom_theme

ggsave_img(p3, "ride_frequency_weekday.png", width = 11)

# --- Final: Close any open graphics devices ---
while (!is.null(dev.list())) dev.off()
