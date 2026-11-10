from chatbot import router as chatbot_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import joblib
from tensorflow.keras.models import load_model

app = FastAPI(title="DiaWell-AI Backend")
app.include_router(chatbot_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
    ],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load models
diabetes_model = joblib.load("models/diabetes_model.pkl")
diabetes_scaler = joblib.load("models/scaler.pkl")

lstm_model = load_model("models/lstm_glucose_model")
glucose_scaler = joblib.load("models/glucose_scaler.pkl")

isolation_model = joblib.load("models/isolation_forest_model.pkl")
isolation_scaler = joblib.load("models/isolation_scaler.pkl")


class RiskInput(BaseModel):
    pregnancies: float
    glucose: float
    blood_pressure: float
    skin_thickness: float
    insulin: float
    bmi: float
    diabetes_pedigree_function: float
    age: float


# Flutter sends {"glucose_readings": [...]}
class GlucoseReadingsInput(BaseModel):
    glucose_readings: list[float]


# Flutter sends {"glucose": x, "previous_glucose": y}
class AnomalyInput(BaseModel):
    glucose: float
    previous_glucose: float


@app.get("/")
def home():
    return {"message": "DiaWell-AI backend is running"}


@app.post("/predict-risk")
def predict_risk(data: RiskInput):
    values = np.array([[
        data.pregnancies,
        data.glucose,
        data.blood_pressure,
        data.skin_thickness,
        data.insulin,
        data.bmi,
        data.diabetes_pedigree_function,
        data.age
    ]])

    scaled_values = diabetes_scaler.transform(values)

    prediction = diabetes_model.predict(scaled_values)[0]
    probability = diabetes_model.predict_proba(scaled_values)[0][1]

    if probability < 0.4:
        risk_level = "Low Risk"
    elif probability < 0.7:
        risk_level = "Medium Risk"
    else:
        risk_level = "High Risk"

    return {
        "prediction": int(prediction),
        "prediction_label": "Diabetic" if prediction == 1 else "Non-Diabetic",
        "risk_level": risk_level,
        "confidence": round(float(probability), 3),
        "message": "This result is for decision support only and is not a medical diagnosis.",
        "decision_support_disclaimer": "This result is for decision support only and is not a medical diagnosis.",
    }


@app.post("/predict-glucose")
def predict_glucose(data: GlucoseReadingsInput):
    if len(data.glucose_readings) != 12:
        return {"error": "Exactly 12 glucose readings are required."}

    readings = np.array(data.glucose_readings).reshape(-1, 1)
    scaled_readings = glucose_scaler.transform(readings)

    model_input = scaled_readings.reshape(1, 12, 1)

    prediction_scaled = lstm_model.predict(model_input)
    prediction = glucose_scaler.inverse_transform(prediction_scaled)[0][0]
    predicted_value = round(float(prediction), 2)

    if predicted_value < 70:
        risk_level = "Hypoglycemia Risk"
    elif predicted_value > 180:
        risk_level = "Hyperglycemia Risk"
    else:
        risk_level = "Normal Range"

    return {
        "predicted_glucose": predicted_value,
        "predicted_next_glucose": predicted_value,
        "risk_level": risk_level,
        "message": "This forecast is for decision support only.",
    }


@app.post("/detect-anomaly")
def detect_anomaly(data: AnomalyInput):
    latest_glucose = data.glucose
    previous_glucose = data.previous_glucose
    glucose_change = latest_glucose - previous_glucose

    features = np.array([[latest_glucose, glucose_change]])
    scaled_features = isolation_scaler.transform(features)

    isolation_prediction = isolation_model.predict(scaled_features)[0]

    if latest_glucose < 70:
        rule_status = "Hypoglycemia"
    elif latest_glucose > 180:
        rule_status = "Hyperglycemia"
    elif glucose_change > 40:
        rule_status = "Sudden Spike"
    elif glucose_change < -40:
        rule_status = "Sudden Drop"
    else:
        rule_status = "Normal"

    ml_status = "Anomaly" if isolation_prediction == -1 else "Normal"
    anomaly_status = "Anomaly" if (isolation_prediction == -1 or rule_status != "Normal") else "Normal"

    if latest_glucose < 54 or latest_glucose > 250:
        risk_level = "High Risk"
    elif latest_glucose < 70 or latest_glucose > 180:
        risk_level = "Medium Risk"
    else:
        risk_level = "Low Risk"

    # Isolation forest score: more negative = more anomalous → map to [0, 1]
    raw_score = float(isolation_model.score_samples(scaled_features)[0])
    confidence = round(max(0.0, min(1.0, -raw_score)), 3)

    return {
        "latest_glucose": latest_glucose,
        "glucose_change": glucose_change,
        "rule_based_status": rule_status,
        "ml_anomaly_status": ml_status,
        "anomaly_status": anomaly_status,
        "risk_level": risk_level,
        "confidence": confidence,
        "message": "This alert is for decision support only.",
    }
