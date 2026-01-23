package com.araimo.tv;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import java.util.ArrayList;
import java.util.List;

public class M3UParser {
    public static List<Channel> parse(String data) {
        List<Channel> channels = new ArrayList<>();
        String[] lines = data.split("\n");
        Channel ch = new Channel();

        for (String line : lines) {
            line = line.trim();
            if (line.isEmpty()) continue;

            if (line.startsWith("#EXTINF")) {
                ch = new Channel();
                // Logo
                if (line.contains("tvg-logo=\"")) {
                    try { ch.logo = line.split("tvg-logo=\"")[1].split("\"")[0]; } catch(Exception e){}
                }
                // Group
                if (line.contains("group-title=\"")) {
                    try { ch.group = line.split("group-title=\"")[1].split("\"")[0]; } catch(Exception e){}
                } else { ch.group = "General"; }
                // Name
                if (line.contains(",")) {
                    ch.name = line.substring(line.lastIndexOf(",") + 1).trim();
                }
            }
            else if (line.startsWith("#EXTVLCOPT:http-referrer=")) {
                ch.referer = line.replace("#EXTVLCOPT:http-referrer=", "").trim();
            }
            else if (line.startsWith("#EXTVLCOPT:http-user-agent=")) {
                ch.userAgent = line.replace("#EXTVLCOPT:http-user-agent=", "").trim();
            }
            else if (line.startsWith("#EXTHTTP:")) {
                try {
                    String json = line.replace("#EXTHTTP:", "").trim();
                    JsonObject obj = new Gson().fromJson(json, JsonObject.class);
                    if(obj.has("cookie")) ch.cookie = obj.get("cookie").getAsString();
                } catch (Exception e) {}
            }
            else if (line.startsWith("http")) {
                ch.url = line;
                channels.add(ch);
            }
        }
        return channels;
    }
}
