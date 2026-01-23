package com.araimo.tv;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import androidx.annotation.NonNull;
import androidx.cardview.widget.CardView;
import androidx.recyclerview.widget.GridLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.bumptech.glide.Glide;
import java.util.List;

public class Adapters {

    // --- Channel Grid Adapter ---
    public static class ChannelAdapter extends RecyclerView.Adapter<ChannelAdapter.Holder> {
        private Context ctx;
        private List<Channel> list;
        private OnItemClick listener;

        public interface OnItemClick { void onClick(Channel c); }

        public ChannelAdapter(Context ctx, List<Channel> list, OnItemClick listener) {
            this.ctx = ctx; this.list = list; this.listener = listener;
        }

        public void updateList(List<Channel> newList) {
            this.list = newList; notifyDataSetChanged();
        }

        public Holder onCreateViewHolder(@NonNull ViewGroup p, int t) {
            // Create CardView Layout programmatically
            CardView card = new CardView(ctx);
            card.setRadius(12f);
            card.setCardBackgroundColor(Color.parseColor("#1E1E1E"));
            
            GridLayoutManager.LayoutParams params = new GridLayoutManager.LayoutParams(GridLayoutManager.LayoutParams.MATCH_PARENT, 350);
            params.setMargins(12, 12, 12, 12);
            card.setLayoutParams(params);

            LinearLayout root = new LinearLayout(ctx);
            root.setOrientation(LinearLayout.VERTICAL);
            root.setGravity(Gravity.CENTER);
            root.setPadding(10, 20, 10, 20);

            ImageView img = new ImageView(ctx);
            img.setLayoutParams(new LinearLayout.LayoutParams(150, 150));
            img.setScaleType(ImageView.ScaleType.FIT_CENTER);

            TextView txt = new TextView(ctx);
            txt.setTextColor(Color.WHITE);
            txt.setTextSize(13f);
            txt.setGravity(Gravity.CENTER);
            txt.setMaxLines(2);
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
            lp.topMargin = 15;
            txt.setLayoutParams(lp);

            root.addView(img); root.addView(txt); card.addView(root);
            return new Holder(card, img, txt);
        }

        public void onBindViewHolder(Holder h, int p) {
            Channel c = list.get(p);
            h.txt.setText(c.name);
            Glide.with(ctx).load(c.logo).placeholder(R.drawable.ic_logo).into(h.img);
            h.itemView.setOnClickListener(v -> listener.onClick(c));
        }

        public int getItemCount() { return list.size(); }
        static class Holder extends RecyclerView.ViewHolder {
            ImageView img; TextView txt;
            Holder(View v, ImageView i, TextView t) { super(v); img=i; txt=t; }
        }
    }

    // --- Category Adapter ---
    public static class CategoryAdapter extends RecyclerView.Adapter<CategoryAdapter.Holder> {
        private List<String> list;
        private String selected;
        private OnCatClick listener;

        public interface OnCatClick { void onClick(String cat); }

        public CategoryAdapter(List<String> list, OnCatClick listener) {
            this.list = list; this.listener = listener; this.selected = "All";
        }

        public Holder onCreateViewHolder(@NonNull ViewGroup p, int t) {
            TextView tv = new TextView(p.getContext());
            tv.setPadding(40, 15, 40, 15);
            tv.setTextColor(Color.WHITE);
            tv.setTextSize(14f);
            
            GradientDrawable shape = new GradientDrawable();
            shape.setCornerRadius(100);
            tv.setBackground(shape);
            
            RecyclerView.LayoutParams pm = new RecyclerView.LayoutParams(-2, -2);
            pm.setMargins(0, 0, 15, 0);
            tv.setLayoutParams(pm);
            return new Holder(tv);
        }

        public void onBindViewHolder(Holder h, int p) {
            String cat = list.get(p);
            h.tv.setText(cat);
            GradientDrawable bg = (GradientDrawable) h.tv.getBackground();
            bg.setColor(selected.equals(cat) ? Color.parseColor("#E50914") : Color.parseColor("#333333"));
            
            h.itemView.setOnClickListener(v -> {
                selected = cat; notifyDataSetChanged(); listener.onClick(cat);
            });
        }

        public int getItemCount() { return list.size(); }
        static class Holder extends RecyclerView.ViewHolder {
            TextView tv; Holder(View v) { super(v); tv = (TextView)v; }
        }
    }
}
