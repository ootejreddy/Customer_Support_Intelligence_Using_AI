import streamlit as st
import pandas as pd
import snowflake.connector
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
from datetime import timedelta

st.set_page_config(
    page_title="Customer Support Intelligence",
    page_icon="🎫",
    layout="wide"
)

st.title("🎫 Customer Support Intelligence Dashboard")
st.markdown("AI-powered ticket analysis with priority and sentiment insights")

@st.cache_resource
def get_connection():
    with open("/Users/saiootejreddy/.snowflake/rsa_key.p8", "rb") as key_file:
        private_key = serialization.load_pem_private_key(
            key_file.read(),
            password=None,
            backend=default_backend()
        )
    
    private_key_bytes = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )
    
    conn = snowflake.connector.connect(
        account="gsvvwno-ts70298",
        user="HASHIRAMASENJU2",
        private_key=private_key_bytes,
        warehouse="SUPPORT_DEV_WH",
        database="SUPPORT_INTEL_DB",
        schema="GOLD"
    )
    return conn

@st.cache_data(ttl=timedelta(minutes=5))
def load_tickets():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT 
            ticket_id,
            subject,
            subject_english,
            body_english,
            language,
            ticket_type,
            ai_category,
            queue,
            original_priority,
            ai_priority,
            sentiment_score,
            sentiment_label,
            priority_rank,
            created_at
        FROM MART_TICKETS_DASHBOARD
        ORDER BY priority_rank, sentiment_score ASC
    """)
    columns = [desc[0] for desc in cursor.description]
    data = cursor.fetchall()
    cursor.close()
    return pd.DataFrame(data, columns=columns)

df = load_tickets()

with st.sidebar:
    st.header("Filters")
    
    priority_filter = st.multiselect(
        "AI Priority",
        options=df['AI_PRIORITY'].unique().tolist(),
        default=df['AI_PRIORITY'].unique().tolist()
    )
    
    sentiment_filter = st.multiselect(
        "Sentiment",
        options=df['SENTIMENT_LABEL'].unique().tolist(),
        default=df['SENTIMENT_LABEL'].unique().tolist()
    )
    
    category_filter = st.multiselect(
        "Category",
        options=df['AI_CATEGORY'].unique().tolist(),
        default=df['AI_CATEGORY'].unique().tolist()
    )

filtered_df = df[
    (df['AI_PRIORITY'].isin(priority_filter)) &
    (df['SENTIMENT_LABEL'].isin(sentiment_filter)) &
    (df['AI_CATEGORY'].isin(category_filter))
]

col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("Total Tickets", len(filtered_df))
with col2:
    st.metric("Critical", len(filtered_df[filtered_df['AI_PRIORITY'].str.contains('critical', case=False, na=False)]))
with col3:
    st.metric("Negative Sentiment", len(filtered_df[filtered_df['SENTIMENT_LABEL'] == 'negative']))
with col4:
    st.metric("Positive Sentiment", len(filtered_df[filtered_df['SENTIMENT_LABEL'] == 'positive']))

col1, col2 = st.columns(2)

with col1:
    with st.container(border=True):
        st.subheader("Tickets by AI Priority")
        priority_counts = filtered_df['AI_PRIORITY'].value_counts().reset_index()
        priority_counts.columns = ['Priority', 'Count']
        st.bar_chart(priority_counts, x='Priority', y='Count')

with col2:
    with st.container(border=True):
        st.subheader("Tickets by Sentiment")
        sentiment_counts = filtered_df['SENTIMENT_LABEL'].value_counts().reset_index()
        sentiment_counts.columns = ['Sentiment', 'Count']
        st.bar_chart(sentiment_counts, x='Sentiment', y='Count')

with st.container(border=True):
    st.subheader("Tickets by Category")
    category_counts = filtered_df['AI_CATEGORY'].value_counts().reset_index()
    category_counts.columns = ['Category', 'Count']
    st.bar_chart(category_counts, x='Category', y='Count')

st.subheader("📋 Ticket Details")

def get_priority_color(priority):
    if 'critical' in str(priority).lower():
        return '🔴'
    elif 'high' in str(priority).lower():
        return '🟠'
    elif 'medium' in str(priority).lower():
        return '🟡'
    return '🟢'

def get_sentiment_color(sentiment):
    if sentiment == 'negative':
        return '😟'
    elif sentiment == 'positive':
        return '😊'
    return '😐'

display_df = filtered_df[['SUBJECT', 'AI_CATEGORY', 'AI_PRIORITY', 'SENTIMENT_LABEL', 'SENTIMENT_SCORE', 'LANGUAGE']].copy()
display_df['Priority'] = display_df['AI_PRIORITY'].apply(lambda x: f"{get_priority_color(x)} {x}")
display_df['Sentiment'] = display_df['SENTIMENT_LABEL'].apply(lambda x: f"{get_sentiment_color(x)} {x}")

st.dataframe(
    display_df[['SUBJECT', 'AI_CATEGORY', 'Priority', 'Sentiment', 'SENTIMENT_SCORE', 'LANGUAGE']],
    column_config={
        "SUBJECT": st.column_config.TextColumn("Subject", width="large"),
        "AI_CATEGORY": st.column_config.TextColumn("Category", width="medium"),
        "Priority": st.column_config.TextColumn("AI Priority", width="medium"),
        "Sentiment": st.column_config.TextColumn("Sentiment", width="small"),
        "SENTIMENT_SCORE": st.column_config.NumberColumn("Score", format="%.2f", width="small"),
        "LANGUAGE": st.column_config.TextColumn("Lang", width="small"),
    },
    hide_index=True,
    use_container_width=True
)

with st.expander("View Ticket Details"):
    selected_ticket = st.selectbox(
        "Select a ticket to view details",
        options=filtered_df['SUBJECT'].tolist()
    )
    
    if selected_ticket:
        ticket = filtered_df[filtered_df['SUBJECT'] == selected_ticket].iloc[0]
        
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("AI Priority", ticket['AI_PRIORITY'])
        with col2:
            st.metric("Sentiment", f"{ticket['SENTIMENT_LABEL']} ({ticket['SENTIMENT_SCORE']:.2f})")
        with col3:
            st.metric("Category", ticket['AI_CATEGORY'])
        
        st.markdown("**Subject (English):**")
        st.info(ticket['SUBJECT_ENGLISH'] or ticket['SUBJECT'])
        
        st.markdown("**Body (English):**")
        st.text_area("", ticket['BODY_ENGLISH'], height=200, disabled=True)
