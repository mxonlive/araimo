package com.araimo.tv;

import android.content.Intent;
import android.os.Bundle;
import android.text.*;
import android.widget.*;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import okhttp3.*;
import java.io.IOException;
import java.util.*;

public class MainActivity extends AppCompatActivity {

    private RecyclerView rvChannels, rvCategories;
    private Adapters.ChannelAdapter channelAdapter;
    private List<Channel> allList = new ArrayList<>();
    private List<String> catList = new ArrayList<>();
    private String currentCat = "All";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        rvChannels = findViewById(R.id.rvChannels);
        rvCategories = findViewById(R.id.rvCategories);
        EditText etSearch = findViewById(R.id.etSearch);

        // Grid
        rvChannels.setLayoutManager(new GridLayoutManager(this, 3));
        channelAdapter = new Adapters.ChannelAdapter(this, new ArrayList<>(), this::openPlayer);
        rvChannels.setAdapter(channelAdapter);

        // Categories
        rvCategories.setLayoutManager(new LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false));

        // Search
        etSearch.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            public void onTextChanged(CharSequence s, int start, int before, int count) { filter(s.toString()); }
            public void afterTextChanged(Editable s) {}
        });

        loadData();
    }

    private void openPlayer(Channel c) {
        Intent i = new Intent(this, PlayerActivity.class);
        i.putExtra("channel", c);
        startActivity(i);
    }

    private void loadData() {
        new OkHttpClient().newCall(new Request.Builder().url("https://raw.githubusercontent.com/abusaeeidx/Mrgify-BDIX-IPTV/main/playlist.m3u").build())
            .enqueue(new Callback() {
                public void onFailure(Call call, IOException e) {}
                public void onResponse(Call call, Response response) throws IOException {
                    if (!response.isSuccessful()) return;
                    
                    List<Channel> data = M3UParser.parse(response.body().string());
                    Set<String> cats = new HashSet<>();
                    for(Channel c : data) cats.add(c.group);
                    
                    runOnUiThread(() -> {
                        allList = data;
                        catList.add("All");
                        catList.addAll(cats);
                        
                        rvCategories.setAdapter(new Adapters.CategoryAdapter(catList, cat -> {
                            currentCat = cat;
                            filter(((EditText)findViewById(R.id.etSearch)).getText().toString());
                        }));
                        
                        channelAdapter.updateList(allList);
                    });
                }
            });
    }

    private void filter(String q) {
        List<Channel> temp = new ArrayList<>();
        for (Channel c : allList) {
            if ((currentCat.equals("All") || c.group.equals(currentCat)) && c.name.toLowerCase().contains(q.toLowerCase())) {
                temp.add(c);
            }
        }
        channelAdapter.updateList(temp);
    }
}
