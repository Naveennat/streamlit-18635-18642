import streamlit as st
import pandas as pd
import numpy as np

def create_ui():
    st.title('StreamlitFinanceApp - minimal')
    if st.button('show'):
        st.write(pd.DataFrame({'a': np.arange(3)}))

if __name__ == '__main__':
    create_ui()
