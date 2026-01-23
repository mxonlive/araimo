package com.araimo.tv;

import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.widget.ProgressBar;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.google.android.exoplayer2.*;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.ui.StyledPlayerView;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;
import java.util.HashMap;
import java.util.Map;

public class PlayerActivity extends AppCompatActivity {

    private ExoPlayer player;
    private StyledPlayerView playerView;
    private ProgressBar loading;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_player);

        playerView = findViewById(R.id.playerView);
        loading = findViewById(R.id.loading);

        Channel c = (Channel) getIntent().getSerializableExtra("channel");
        if (c != null) startPlayer(c);
    }

    private void startPlayer(Channel c) {
        // Headers Config
        Map<String, String> headers = new HashMap<>();
        String ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
        
        if (c.userAgent != null && !c.userAgent.isEmpty()) ua = c.userAgent;
        headers.put("User-Agent", ua);
        
        if (c.referer != null && !c.referer.isEmpty()) {
            headers.put("Referer", c.referer);
            headers.put("Origin", "https://" + Uri.parse(c.referer).getHost());
        }
        if (c.cookie != null && !c.cookie.isEmpty()) headers.put("Cookie", c.cookie);

        DefaultHttpDataSource.Factory dsf = new DefaultHttpDataSource.Factory()
                .setUserAgent(ua)
                .setAllowCrossProtocolRedirects(true)
                .setDefaultRequestProperties(headers);

        MediaSource mediaSource = new HlsMediaSource.Factory(dsf)
                .createMediaSource(MediaItem.fromUri(Uri.parse(c.url)));

        player = new ExoPlayer.Builder(this).build();
        playerView.setPlayer(player);
        player.setMediaSource(mediaSource);
        player.prepare();
        player.play();

        player.addListener(new Player.Listener() {
            public void onPlaybackStateChanged(int state) {
                loading.setVisibility(state == Player.STATE_BUFFERING ? View.VISIBLE : View.GONE);
            }
            public void onPlayerError(PlaybackException error) {
                Toast.makeText(PlayerActivity.this, "Error: " + error.getMessage(), Toast.LENGTH_LONG).show();
            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (player != null) player.release();
    }
}
