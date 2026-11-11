create_the_best_map <- function(coords, file = NULL) {
  # Убедимся, что необходимые библиотеки подключены
  require(tidyverse)
  require(leaflet)
  require(mapview)
  
  # Обработка данных
  df_map <- coords %>% 
    filter(!is.na(lat), !is.na(lon)) %>%
    mutate(Year = as.numeric(Data)) %>%
    group_by(Geo, lat, lon) %>%
    summarise(
      n_samples = n(),
      unique_years = paste(sort(unique(Year)), collapse = ", "),
      has_year = any(!is.na(Year)),
      # Создаем HTML-метку     ),
      .groups = 'drop'
    )  %>%
    mutate(
      # Подготовим год для отображения в метке
      label_year = ifelse(
        has_year,
        paste0(" (", unique_years, " BP", ")"),
        ""
      ),
      # 🔵 Цвет метки: зелёный — если год есть, серый — если нет
      marker_color = ifelse(has_year, "#07cc00", "#6f6a66"),
      # Формируем метку: "число (год)"
      label_text = sprintf(
        '<span style="color: %s; font-weight: bold;">%d%s</span>',
        marker_color, n_samples, label_year
      )
    )
  # Проверка на наличие данных
  if (nrow(df_map) == 0) {
    warning("Нет данных для отображения после фильтрации")
    return(NULL)
  }

  mean_lat <- mean(df_map$lat, na.rm = TRUE)
  mean_lng <- mean(df_map$lon, na.rm = TRUE)
  
  # Создание карты
  map <- leaflet(df_map, options = leafletOptions(minZoom = 1, maxZoom = 10)) %>%
    addProviderTiles("Esri.WorldPhysical")  %>%
    setView(lng = mean_lng, lat = mean_lat, zoom = 4) %>%
    addMarkers(
      lng = ~lon,
      lat = ~lat,
      label = lapply(df_map$label_text, htmltools::HTML),
      labelOptions = labelOptions(
        noHide = TRUE,
        direction = "top",
        offset = c(0, -25),
        style = list(
          "font-weight" = "bold",
          "font-size" = "13px",
          "text-shadow" = "1px 1px 2px white",
          "white-space" = "nowrap",
          "background-color" = "rgba(255, 255, 255, 0.85)",
          "padding" = "1px 6px",
          "border-radius" = "4px",
          "border" = "1px solid #ccc"
        )
      ),
      popup = ~paste(
        "<b>", Geo, "</b><br>",
        "<b>Всего образцов:</b> ", n_samples, "<br>",
        "<b>Годы:</b> ", unique_years, "<br>"
      )
    )
    
  
  # Выводим информацию о созданной карте
  cat("Карта создана. Отображаются локации:", paste(df_map$Geo, collapse = "; "), "\n")
  cat("Количество локаций:", nrow(df_map), "\n")
  
  # Сохраняем карту если указан путь к файлу
  if (!is.null(file)) {
    saveWidget(map, file = file)
    cat("Карта сохранена в файл:", file, "\n")
  }
  
  return(map)
}